module AssetSync
  class Storage

    class BucketNotFound < StandardError; end

    class BucketConnectionError < StandardError; end

    attr_accessor :config

    def initialize(cfg)
      @config = cfg
    end

    def bucket
      @bucket ||= UpyunRainbow::Util.new self.config.upyun_bucket, self.config.upyun_username, self.config.upyun_password, self.config.upyun_api_host
    end

    def log(msg)
      AssetSync.log(msg)
    end

    def keep_existing_remote_files?
      self.config.existing_remote_files?
    end

    def path
      Rails.public_path
    end

    def local_files
      @local_files ||= get_local_files
    end

    def get_local_files
      if self.config.manifest
        if File.exists?(self.config.manifest_path)
          yml = YAML.load(IO.read(self.config.manifest_path))
          log "Using: Manifest #{self.config.manifest_path}"
          return yml.values.map { |f| File.join(self.config.assets_prefix, f) }
        else
          log "Warning: manifest.yml not found at #{self.config.manifest_path}"
        end
      end
      log "Using: Directory Search of #{path}/#{self.config.assets_prefix}"
      Dir.chdir(path) do
        Dir["#{self.config.assets_prefix}/**/**"]
      end
    end

    def get_remote_files
      # raise BucketNotFound.new("#{self.config.fog_provider} Bucket: #{self.config.fog_directory} not found.") unless bucket
      # fixes: https://github.com/rumblelabs/asset_sync/issues/16
      #        (work-around for https://github.com/fog/fog/issues/596)
      files = []
      result, code = bucket.list("/#{self.config.assets_prefix}")
      if code == 200 and result.size > 0
        result.each {|f| files << "#{self.config.assets_prefix}/#{f[:name]}" }
      end
      return files
    end

    def delete_file(f, remote_files_to_delete)
      if remote_files_to_delete.include?(f)
        log "Deleting: #{f}"
        bucket.delete "/#{f}"
      end
    end

    def delete_extra_remote_files
      log "Fetching files to flag for delete"
      remote_files = get_remote_files
      # fixes: https://github.com/rumblelabs/asset_sync/issues/19
      from_remote_files_to_delete = remote_files - local_files

      log "Flagging #{from_remote_files_to_delete.size} file(s) for deletion"
      # Delete unneeded remote files
      result, code = bucket.list("/#{self.config.assets_prefix}")
      if code == 200 and result.size > 0
        result.each do |f|
          delete_file "#{self.config.assets_prefix}/#{f[:name]}", from_remote_files_to_delete
        end
      end
    end

    def upload_file(f)
      log "Uploading: /#{f}"
      result, code = bucket.post("/#{f}", File.open("#{path}/#{f}"))
      if result != :ok
        raise BucketConnectionError.new("Failed to upload /#{f}. Check your network connection and upyun configuration.")
      end
    end

    def upload_files
      # get a fresh list of remote files
      remote_files = get_remote_files
      # fixes: https://github.com/rumblelabs/asset_sync/issues/19
      local_files_to_upload = local_files - remote_files

      # Upload new files
      local_files_to_upload.each do |f|
        next unless File.file? "#{path}/#{f}" # Only files.
        upload_file f
      end
    end

    def sync
      # fixes: https://github.com/rumblelabs/asset_sync/issues/19
      log "AssetSync: Syncing."
      upload_files
      delete_extra_remote_files unless keep_existing_remote_files?
      log "AssetSync: Done."
    end

  end
end
