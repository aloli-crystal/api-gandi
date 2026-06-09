require "json"

module GandiApi::Endpoints
  # Un enregistrement (rrset) d'une zone LiveDNS.
  struct Record
    include JSON::Serializable

    @[JSON::Field(key: "rrset_name")]
    getter name : String
    @[JSON::Field(key: "rrset_type")]
    getter type : String
    @[JSON::Field(key: "rrset_ttl")]
    getter ttl : Int32
    @[JSON::Field(key: "rrset_values")]
    getter values : Array(String)
  end

  # Gestion des enregistrements d'une zone Gandi LiveDNS.
  #
  # `ensure_record` est *idempotent* : il fait un `PUT` du rrset
  # `(nom, type)`, ce qui le crée s'il n'existe pas et remplace ses
  # valeurs sinon. Relancer avec la même valeur est un no-op effectif.
  class LiveDns
    DEFAULT_TTL = 300

    def initialize(@client : GandiApi::Client)
    end

    # Liste tous les enregistrements de la zone `fqdn`.
    def list_records(fqdn : String) : Array(Record)
      body = @client.call("GET", "/domains/#{fqdn}/records")
      return [] of Record unless body
      Array(Record).from_json(body.to_json)
    end

    # Récupère le rrset `(name, type)` ou nil s'il n'existe pas.
    def get_record(fqdn : String, name : String, type : String) : Record?
      body = @client.call("GET", "/domains/#{fqdn}/records/#{rrset_name(name)}/#{type}")
      return nil unless body
      Record.from_json(body.to_json)
    rescue GandiApi::NotFound
      nil
    end

    # Crée ou remplace (PUT idempotent) le rrset `(name, type)` avec
    # `values`. `name` vide ou "@" cible la racine de la zone.
    def ensure_record(
      fqdn : String,
      type : String,
      name : String,
      values : Array(String),
      ttl : Int32 = DEFAULT_TTL,
    ) : Nil
      @client.call(
        "PUT",
        "/domains/#{fqdn}/records/#{rrset_name(name)}/#{type}",
        body: {rrset_ttl: ttl, rrset_values: values},
      )
    end

    # Variante mono-valeur (cas le plus courant : un A/AAAA/CNAME).
    def ensure_record(fqdn : String, type : String, name : String, value : String, ttl : Int32 = DEFAULT_TTL) : Nil
      ensure_record(fqdn, type, name, [value], ttl)
    end

    # Supprime le rrset `(name, type)`.
    def delete_record(fqdn : String, name : String, type : String) : Nil
      @client.call("DELETE", "/domains/#{fqdn}/records/#{rrset_name(name)}/#{type}")
    end

    # Gandi attend "@" pour la racine de la zone.
    private def rrset_name(name : String) : String
      name.empty? ? "@" : name
    end
  end
end
