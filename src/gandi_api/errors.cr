module GandiApi
  # Erreur générique de l'API Gandi. Sous-classes par catégorie pour
  # que l'appelant puisse réagir (auth, not found, rate limit).
  class ApiError < Exception
    getter status_code : Int32?

    def initialize(message : String, @status_code : Int32? = nil)
      super(message)
    end
  end

  # HTTP 401/403 — PAT invalide, révoqué ou scope insuffisant.
  class AuthenticationError < ApiError
  end

  # HTTP 404 — domaine ou enregistrement inexistant.
  class NotFound < ApiError
  end

  # HTTP 429 — throttling Gandi. `retry_after` si fourni.
  class RateLimited < ApiError
    getter retry_after : Int32?

    def initialize(message : String, @retry_after : Int32? = nil)
      super(message)
    end
  end
end
