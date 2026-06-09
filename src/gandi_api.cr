# Client Crystal pour l'API Gandi LiveDNS v5 (stdlib uniquement).
#
#     client = GandiApi::Client.new(token: ENV["GANDI_PAT"])
#     client.livedns.ensure_record("quimeo.fr", "A", "www", "203.0.113.7")
require "./gandi_api/version"
require "./gandi_api/errors"
require "./gandi_api/client"
require "./gandi_api/endpoints/livedns"

module GandiApi
end
