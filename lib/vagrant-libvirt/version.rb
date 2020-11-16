module VagrantPlugins
  module ProviderLibvirt
    VERSION_FILE = File.dirname(__FILE__) + "/version"

    def self.get_version
      if File.exist?(VERSION_FILE)
        version = File.read(VERSION_FILE)
      else
        git_version = `git describe --tags`
        version_parts = git_version.split('-').first(2) # drop the git sha if it exists
        if version_parts.length > 1
          # increment the patch number so that this is marked as a pre-release of the
          # next possible release
          main_version_parts = Gem::Version.new(version_parts[0]).segments
          main_version_parts[-1] = main_version_parts.last + 1
          version_parts = main_version_parts + ["pre", version_parts[1]]
        end
        version = version_parts.join(".")
      end

      return version.freeze
    end

    def self.write_version
      File.write(VERSION_FILE, self.get_version)
    end
  end
end
