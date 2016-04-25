module Lita
  module Handlers
    class Stats < Handler
      route(
        /\Astate of SV.CO for batch *(\d*) *\?\z/,
        :state_of_batch,
        command: true,
        restrict_to: :sv_co_team,
        help: { 'state of SV.CO for batch N?' => I18n.t('slack.help.state_of_svco') }
      )

      route(
        /\Aexpired team targets for batch *(\d*) *\?\z/,
        :expired_team_targets,
        command: true,
        restrict_to: :sv_co_team,
        help: { 'expired team targets for batch N?' => I18n.t('slack.help.expired_team_targets') }
      )

      def state_of_batch(response)
        # lets avoid the need to pass response around
        @response = response

        ActiveRecord::Base.connection_pool.with_connection do
          @batch_requested = parse_batch_from_command
          @batch_requested.present? ? reply_with_state_of_batch : send_batch_missing_message
        end
      end

      def expired_team_targets(response)
        @response = response

        ActiveRecord::Base.connection_pool.with_connection do
          @batch_requested = parse_batch_from_command
          @batch_requested.present? ? reply_with_expired_team_targets : send_batch_missing_message
        end
      end

      def parse_batch_from_command
        @response.match_data[1].present? ? ::Batch.find_by_batch_number(@response.match_data[1].to_i) : nil
      end

      def send_batch_missing_message
        @response.reply I18n.t('slack.handlers.stats.batch_missing_error')
      end

      def reply_with_state_of_batch
        @response.reply batch_state_message
      end

      def reply_with_expired_team_targets
        @response.reply expired_team_targets_details
      end

      def batch_state_message
        <<~MESSAGE
          > *State of SV.CO Batch #{@batch_requested.batch_number} (#{@batch_requested.name}):*
          Total number of startups: #{total_startups_count_and_names}
          #{stage_wise_startup_counts_and_names}
          Number of inactive startups last week: #{inactive_startups_count_and_names}
          Number of startups in danger zone: #{endangered_startups_count_and_names}
        MESSAGE
      end

      def total_startups_count_and_names
        names_list = list_of_names(@batch_requested.startups)
        "#{@batch_requested.startups.count} #{names_list}\n"
      end

      def stage_wise_startup_counts_and_names
        response = ''
        stages = @batch_requested.startups.pluck(:stage).uniq

        stages.each do |stage|
          response += 'Number of startups in _\'' + I18n.t("timeline_event.stage.#{stage}") + '\'_ stage: '
          startups = Startup.where(stage: stage, batch: @batch_requested)
          response += startups.count.to_s + " #{list_of_names(startups)}\n"
        end

        response
      end

      def inactive_startups_count_and_names
        startups = @batch_requested.startups.inactive_for_week
        names_list = list_of_names(startups)
        "#{startups.count} #{names_list}\n"
      end

      def endangered_startups_count_and_names
        startups = @batch_requested.startups.endangered
        names_list = list_of_names(startups)
        "#{startups.count} #{names_list}\n"
      end

      def list_of_names(startups)
        return '' unless startups.present?
        '(' + startups.map { |startup| "<#{Rails.application.routes.url_helpers.startup_url(startup)}|#{startup.product_name}>" }.join(', ') + ')'
      end

      def expired_team_targets_details
        <<~MESSAGE
          > *Targets expired last week for SV.CO Batch #{@batch_requested.batch_number} (#{@batch_requested.name}):*
          #{expired_team_targets_list}
        MESSAGE
      end

      def expired_team_targets_list
        targets = Target.for_startups_in_batch(@batch_requested).expired_last_week

        return I18n.t('slack.handlers.stats.no_expired_targets') unless targets.present?

        targets_list = ''
        targets.each_with_index do |target, index|
          targets_list += "#{index + 1}. #{target.startup.product_name}: _'#{target.title}'_\n"
        end

        targets_list
      end
    end

    Lita.register_handler(Stats)
  end
end
