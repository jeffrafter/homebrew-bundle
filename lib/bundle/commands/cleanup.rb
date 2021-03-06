module Bundle
  module Commands
    module Cleanup
      module_function

      def reset!
        @dsl = nil
        Bundle::CaskDumper.reset!
        Bundle::BrewDumper.reset!
        Bundle::TapDumper.reset!
        Bundle::BrewServices.reset!
      end

      def run
        casks = casks_to_uninstall
        formulae = formulae_to_uninstall
        taps = taps_to_untap
        if ARGV.force?
          if casks.any?
            Kernel.system "brew", "cask", "uninstall", "--force", *casks
            puts "Uninstalled #{casks.size} cask#{casks.size == 1 ? "" : "s"}"
          end

          if formulae.any?
            Kernel.system "brew", "uninstall", "--force", *formulae
            puts "Uninstalled #{formulae.size} formula#{formulae.size == 1 ? "" : "e"}"
          end

          if taps.any?
            Kernel.system "brew", "untap", *taps
          end
        else
          require "utils/formatter"

          if casks.any?
            puts "Would uninstall casks:"
            puts Formatter.columns casks
          end

          if formulae.any?
            puts "Would uninstall formulae:"
            puts Formatter.columns formulae
          end

          if taps.any?
            puts "Would untap:"
            puts Formatter.columns taps
          end
        end
      end

      def casks_to_uninstall
        @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
        kept_casks = @dsl.entries.select { |e| e.type == :cask }.map(&:name)
        current_casks = Bundle::CaskDumper.casks
        current_casks - kept_casks
      end

      def formulae_to_uninstall
        @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
        kept_formulae = @dsl.entries.select { |e| e.type == :brew }.map(&:name)
        kept_formulae.map! do |f|
          Bundle::BrewDumper.formula_aliases[f] ||
            Bundle::BrewDumper.formula_oldnames[f] ||
            f
        end
        current_formulae = Bundle::BrewDumper.formulae
        current_formulae.each do |f|
          next unless kept_formulae.include?(f[:name])
          next unless f[:dependencies]
          kept_formulae += f[:dependencies]
        end
        kept_formulae.uniq!
        current_formulae.reject! do |f|
          Bundle::BrewInstaller.formula_in_array?(f[:full_name], kept_formulae)
        end
        current_formulae.map { |f| f[:full_name] }
      end

      IGNORED_TAPS = %w[homebrew/core homebrew/bundle].freeze

      def taps_to_untap
        @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
        kept_taps = @dsl.entries.select { |e| e.type == :tap }.map(&:name)
        current_taps = Bundle::TapDumper.tap_names
        current_taps - kept_taps - IGNORED_TAPS
      end
    end
  end
end
