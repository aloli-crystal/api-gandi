require "spec"
require "../src/gandi_api"

# Transport HTTP factice : enregistre les requêtes émises et renvoie
# des réponses stubées par (méthode, motif d'URL). Le dernier stub
# déclaré qui matche gagne.
class FakeTransport < GandiApi::HttpTransport
  record Request, method : String, url : String, headers : HTTP::Headers, body : String
  record Stub, method : String, url_pattern : Regex, status : Int32, body : String

  getter requests = [] of Request
  getter stubs = [] of Stub

  def stub(method : String, url_pattern : Regex, status : Int32 = 200, body : String = "") : Nil
    @stubs << Stub.new(method, url_pattern, status, body)
  end

  def request(method, url, headers, body) : {Int32, String}
    @requests << Request.new(method, url, headers, body)
    match = @stubs.reverse.find { |s| s.method == method && s.url_pattern.matches?(url) }
    raise "Aucun stub pour #{method} #{url}" unless match
    {match.status, match.body}
  end

  def last : Request
    @requests.last
  end
end

def build_client(transport : FakeTransport) : GandiApi::Client
  GandiApi::Client.new(token: "pat-test", transport: transport)
end
