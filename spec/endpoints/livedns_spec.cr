require "../spec_helper"

describe GandiApi::Endpoints::LiveDns do
  describe "#ensure_record" do
    it "fait un PUT idempotent du rrset avec la valeur" do
      t = FakeTransport.new
      t.stub("PUT", %r{/domains/quimeo\.fr/records/www/A$}, status: 201, body: %({"message":"ok"}))
      build_client(t).livedns.ensure_record("quimeo.fr", "A", "www", "203.0.113.7")

      req = t.last
      req.method.should eq("PUT")
      req.url.should end_with("/domains/quimeo.fr/records/www/A")
      req.headers["Authorization"].should eq("Bearer pat-test")
      JSON.parse(req.body)["rrset_values"].as_a.map(&.as_s).should eq(["203.0.113.7"])
      JSON.parse(req.body)["rrset_ttl"].as_i.should eq(300)
    end

    it "cible la racine de la zone avec @ quand le nom est vide" do
      t = FakeTransport.new
      t.stub("PUT", %r{/records/@/AAAA$}, status: 201, body: "")
      build_client(t).livedns.ensure_record("quimeo.fr", "AAAA", "", "2001:db8::1")
      t.last.url.should end_with("/records/@/AAAA")
    end

    it "accepte plusieurs valeurs (ex: TXT, round-robin)" do
      t = FakeTransport.new
      t.stub("PUT", %r{/records/@/TXT$}, status: 201, body: "")
      build_client(t).livedns.ensure_record("quimeo.fr", "TXT", "@", ["v=spf1 -all", "extra"])
      JSON.parse(t.last.body)["rrset_values"].as_a.size.should eq(2)
    end
  end

  describe "#list_records" do
    it "parse la liste des rrsets" do
      t = FakeTransport.new
      t.stub("GET", %r{/domains/quimeo\.fr/records$}, status: 200,
        body: %([{"rrset_name":"www","rrset_type":"A","rrset_ttl":300,"rrset_values":["203.0.113.7"]}]))
      records = build_client(t).livedns.list_records("quimeo.fr")
      records.size.should eq(1)
      records.first.name.should eq("www")
      records.first.values.should eq(["203.0.113.7"])
    end
  end

  describe "#get_record" do
    it "retourne nil sur 404" do
      t = FakeTransport.new
      t.stub("GET", %r{/records/absent/A$}, status: 404, body: %({"message":"not found"}))
      build_client(t).livedns.get_record("quimeo.fr", "absent", "A").should be_nil
    end
  end

  describe "auth errors" do
    it "lève AuthenticationError sur 401" do
      t = FakeTransport.new
      t.stub("GET", %r{/records$}, status: 401, body: %({"message":"bad token"}))
      expect_raises(GandiApi::AuthenticationError) do
        build_client(t).livedns.list_records("quimeo.fr")
      end
    end
  end
end
