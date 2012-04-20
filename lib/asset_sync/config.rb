module AssetSync
  class Config
    include ActiveModel::Validations

    class Invalid < StandardError; end

    # AssetSync
    attr_accessor :existing_remote_files # What to do with your existing remote files? (keep or delete)
    attr_accessor :gzip_compression
    attr_accessor :manifest
    attr_accessor :fail_silently

    # Upyun configuration
    attr_accessor :upyun_api_host, :upyun_bucket, :upyun_username, :upyun_password

    validates :existing_remote_files, :inclusion => { :in => %w(keep delete) }

    validates :upyun_api_host,        :presence => true
    validates :upyun_bucket,          :presence => true
    validates :upyun_username,        :presence => true
    validates :upyun_password,        :presence => true

    def initialize
      self.existing_remote_files = 'keep'
      self.gzip_compression = false
      self.manifest = false
      self.fail_silently = false
      self.upyun_api_host = "http://v0.api.upyun.com"
      load_yml! if yml_exists?
    end

    def manifest_path
      directory =
        Rails.application.config.assets.manifest || default_manifest_directory
      File.join(directory, "manifest.yml")
    end

    def gzip?
      self.gzip_compression
    end

    def existing_remote_files?
      (self.existing_remote_files == "keep")
    end

    def fail_silently?
      fail_silently == true
    end

    def yml_exists?
      File.exists?(self.yml_path)
    end

    def yml
      @yml ||= YAML.load(ERB.new(IO.read(yml_path)).result)[Rails.env] rescue nil || {}
    end

    def yml_path
      Rails.root.join("config", "asset_sync.yml").to_s
    end

    def assets_prefix
      # Fix for Issue #38 when Rails.config.assets.prefix starts with a slash
      Rails.application.config.assets.prefix.sub(/^\//, '')
    end

    def load_yml!
      self.upyun_bucket           = yml["upyun_bucket"]
      self.upyun_username         = yml["upyun_username"]
      self.upyun_password         = yml["upyun_password"]
      self.upyun_api_host    = yml["upyun_api_host"] if yml.has_key?("upyun_api_host")
      self.existing_remote_files  = yml["existing_remote_files"] if yml.has_key?("existing_remote_files")
      self.gzip_compression       = yml["gzip_compression"] if yml.has_key?("gzip_compression")
      self.manifest               = yml["manifest"] if yml.has_key?("manifest")
      self.fail_silently          = yml["fail_silently"] if yml.has_key?("fail_silently")
    end


  private

    def default_manifest_directory
      File.join(Rails.public_path, assets_prefix)
    end
  end
end
