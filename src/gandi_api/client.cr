require "http/client"
require "json"
require "uri"

require "./errors"

module GandiApi
  # Racine de l'API Gandi LiveDNS v5.
  DEFAULT_ENDPOINT = "https://api.gandi.net/v5/livedns"

  # Transport HTTP abstrait — permet d'injecter un double dans les
  # tests. Retourne `{status, body}` ; le `Client` décode le JSON et
  # lève les exceptions.
  abstract class HttpTransport
    abstract def request(
      method : String,
      url : String,
      headers : HTTP::Headers,
      body : String,
    ) : {Int32, String}
  end

  # Transport par défaut basé sur `HTTP::Client` de la stdlib.
  class DefaultHttpTransport < HttpTransport
    def request(method, url, headers, body) : {Int32, String}
      response = HTTP::Client.exec(
        method: method,
        url: url,
        headers: headers,
        body: body.empty? ? nil : body,
      )
      {response.status_code, response.body}
    end
  end

  # Client Gandi LiveDNS v5.
  #
  # Auth par *Personal Access Token* (PAT), passé en `Authorization:
  # Bearer <token>`. Le PAT se génère depuis le compte Gandi
  # (Paramètres du compte → « Personal Access Tokens »), avec la
  # permission « Gérer le DNS » sur l'organisation/le domaine voulu.
  #
  # ```
  # client = GandiApi::Client.new(token: ENV["GANDI_PAT"])
  # client.livedns.ensure_record("quimeo.fr", "A", "www", "203.0.113.7")
  # ```
  class Client
    getter token : String
    getter endpoint : String
    property transport : HttpTransport

    def initialize(
      @token : String,
      @endpoint : String = DEFAULT_ENDPOINT,
      @transport : HttpTransport = DefaultHttpTransport.new,
    )
    end

    # Appel API. `path` est relatif au endpoint (ex.
    # `/domains/quimeo.fr/records`). `body` est JSON-sérialisable.
    def call(
      method : String,
      path : String,
      query : Hash(String, String)? = nil,
      body = nil,
    ) : JSON::Any?
      url = build_url(path, query)
      body_str = serialize_body(body)
      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@token}",
        "Accept"        => "application/json",
        "Content-Type"  => "application/json",
      }
      status, response_body = @transport.request(method, url, headers, body_str)
      handle_response(status, response_body, method, path)
    end

    private def build_url(path : String, query : Hash(String, String)?) : String
      full = @endpoint + (path.starts_with?("/") ? path : "/#{path}")
      if query && !query.empty?
        pairs = query.map { |k, v| "#{URI.encode_path_segment(k)}=#{URI.encode_path_segment(v)}" }
        full + "?" + pairs.join("&")
      else
        full
      end
    end

    private def serialize_body(body) : String
      case body
      when Nil    then ""
      when String then body
      else             body.to_json
      end
    end

    private def handle_response(status : Int32, body : String, method : String, path : String) : JSON::Any?
      case status
      when 200..299
        return if body.empty?
        JSON.parse(body)
      when 401, 403
        raise AuthenticationError.new(format_error(status, body, method, path), status)
      when 404
        raise NotFound.new(format_error(status, body, method, path), status)
      when 429
        raise RateLimited.new(format_error(status, body, method, path), extract_retry_after(body))
      else
        raise ApiError.new(format_error(status, body, method, path), status)
      end
    end

    private def format_error(status : Int32, body : String, method : String, path : String) : String
      "Gandi LiveDNS #{method} #{path} → HTTP #{status} : #{body.empty? ? "(corps vide)" : body}"
    end

    private def extract_retry_after(body : String) : Int32?
      JSON.parse(body)["retry_after"]?.try(&.as_i?)
    rescue
      nil
    end

    # Accès paresseux à l'endpoint LiveDNS (un seul objet par Client).
    def livedns : Endpoints::LiveDns
      @livedns ||= Endpoints::LiveDns.new(self)
    end

    @livedns : Endpoints::LiveDns?
  end
end
