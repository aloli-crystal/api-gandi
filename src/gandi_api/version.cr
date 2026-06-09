module GandiApi
  # Lue au compile-time depuis `shard.yml` (convention ALOLI :
  # une seule source de vérité pour la version, cf. note mémoire
  # `feedback_shard_version_macro.md`).
  VERSION = {{
              (read_file("#{__DIR__}/../../shard.yml")
                .lines
                .find(&.starts_with?("version:")) || "version: 0.0.0")
                .gsub(/^version:\s*/, "")
                .chomp
            }}
end
