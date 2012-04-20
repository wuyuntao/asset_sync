class Engine < Rails::Engine

  engine_name "asset_sync"

  initializer "asset_sync config", :group => :all do |app|
    app_initializer = Rails.root.join('config', 'initializers', 'asset_sync.rb').to_s
    app_yaml = Rails.root.join('config', 'asset_sync.yml').to_s

    if File.exists?( app_initializer )
      AssetSync.log "AssetSync: using #{app_initializer}"
      load app_initializer
    elsif !File.exists?( app_initializer ) && !File.exists?( app_yaml )
      AssetSync.log "AssetSync: using default configuration from built-in initializer"
      AssetSync.configure do |config|
        config.upyun_api_host = ENV['UPYUN_API_HOST'] || "http://v0.api.upyun.com"
        config.upyun_bucket = ENV['UPYUN_BUCKET']
        config.upyun_username = ENV['UPYUN_USERNAME']
        config.upyun_password = ENV['UPYUN_PASSWORD']

        config.existing_remote_files = ENV['ASSET_SYNC_EXISTING_REMOTE_FILES'] || "keep"
        config.gzip_compression = ENV['ASSET_SYNC_GZIP_COMPRESSION'] == 'true'
        config.manifest = ENV['ASSET_SYNC_MANIFEST'] == 'true'
      end
    end

    if File.exists?( app_yaml )
      AssetSync.log "AssetSync: YAML file found #{app_yaml} settings will be merged into the configuration"
    end
  end

end
