require 'securerandom'
require 'language_pack'
require 'language_pack/rails5'

class LanguagePack::Rails51 < LanguagePack::Rails5
  # @return [Boolean] true if it's a Rails 5.1.x app
  def self.use?
    instrument "rails51.use" do
      rails_version = bundler.gem_version('railties')
      return false unless rails_version
      is_rails = rails_version >= Gem::Version.new('5.1.x')
      return is_rails
    end
  end

  private

    def run_assets_precompile_rake_task
      instrument "rails51.run_assets_precompile_rake_task" do
        log("assets_precompile") do
          if Dir.glob("public/assets/{.sprockets-manifest-*.json,manifest-*.json}", File::FNM_DOTMATCH).any?
            puts "Detected manifest file, assuming assets were compiled locally"
            return true
          end

          precompile = rake.task("assets:precompile")
          return true unless precompile.is_defined?

          topic("Preparing app for Rails asset pipeline")

          load_asset_cache

          precompile.invoke(env: rake_env)

          if precompile.success?
            log "assets_precompile", :status => "success"
            puts "Asset precompilation completed (#{"%.2f" % precompile.time}s)"

            puts "Cleaning assets"
            rake.task("assets:clean").invoke(env: rake_env)

            store_asset_cache if store_cache?
            cleanup_assets_cache
          else
            precompile_fail(precompile.output)
          end
        end
      end
    end

    def store_cache?
      # the last dyno of the formation in heroku ci
      env('CI_NODE_INDEX').to_i == (env('CI_NODE_TOTAL').to_i - 1)
    end

    def node_modules_folder
      "node_modules"
    end

    def public_packs_folder
      "public/packs"
    end

    def public_packs_test_folder
      "public/packs-test"
    end

    def webpacker_cache_folder
      "tmp/cache/webpacker"
    end

    def load_asset_cache
      puts "Loading asset cache"
      start = Time.now
      @cache.load_without_overwrite public_assets_folder
      @cache.load default_assets_cache
      @cache.load_without_overwrite public_packs_folder
      @cache.load_without_overwrite public_packs_test_folder
      @cache.load node_modules_folder
      @cache.load webpacker_cache_folder
      puts "Took #{Time.now - start}s loading asset cache"
    end

    def store_asset_cache
      puts "Storing asset cache"
      start = Time.now
      @cache.store public_assets_folder
      @cache.store default_assets_cache
      @cache.store public_packs_folder
      @cache.store public_packs_test_folder
      @cache.store node_modules_folder
      @cache.store webpacker_cache_folder
      puts "Took #{Time.now - start}s storing asset cache"
    end
end
