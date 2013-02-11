require 'whitehall/document_filter/filterer'

module Whitehall::DocumentFilter
  class Rummager < Filterer
    attr_accessor :edition_eager_load
    def edition_eager_load
      @edition_eager_load ||= [:document, :organisations]
    end

    def announcements_search
      filter_args =
        standard_filter_args
          .merge(filter_by_announcement_type)

      @results = Whitehall.government_search_client.advanced_search(filter_args)
    end

    def publications_search
      filter_args =
        standard_filter_args
          .merge(filter_by_publication_type)

      self.edition_eager_load += [:attachments, {response: :attachments}]
      @results = Whitehall.government_search_client.advanced_search(filter_args)
    end

    def policies_search
      filter_args =
        standard_filter_args
          .merge(search_format_types: [Policy.search_format_type])

      @results = Whitehall.government_search_client.advanced_search(filter_args)
    end

    def default_filter_args
      @default = {
        page: @page.to_s,
        per_page: @per_page.to_s
      }
    end

    def standard_filter_args
      default_filter_args
        .merge(filter_by_keywords)
        .merge(filter_by_relevance_to_local_government)
        .merge(filter_by_people)
        .merge(filter_by_topics)
        .merge(filter_by_organisations)
        .merge(filter_by_locations)
        .merge(filter_by_date)
        .merge(sort)
    end

    def filter_by_keywords
      if @keywords.present?
        {keywords: @keywords.to_s}
      else
        {}
      end
    end

    def filter_by_relevance_to_local_government
      {relevant_to_local_government: relevant_to_local_government.to_s}
    end

    def filter_by_people
      if @people_ids.present? && @people_ids != ["all"]
        {people: @people_ids.map(&:to_s)}
      else
        {}
      end
    end

    def filter_by_topics
      if selected_topics.any?
        {topics: selected_topics.map(&:id).map(&:to_s)}
      else
        {}
      end
    end

    def filter_by_organisations
      if selected_organisations.any?
        {organisations: selected_organisations.map(&:id).map(&:to_s)}
      else
        {}
      end
    end

    def filter_by_locations
      if selected_locations.any?
        {world_locations: selected_locations.map(&:slug)}
      else
        {}
      end
    end

    def filter_by_date
      if @date.present? && @direction.present?
        case @direction
        when "before"
          {public_timestamp: {before: (@date - 1.day).to_s(:db)}}
        when "after"
          {public_timestamp: {after: @date.to_s(:db) }}
        else
          {}
        end
      else
        {}
      end
    end

    def sort
      if @direction.present? && @keywords.blank?
        case @direction
        when "before"
          {order: { public_timestamp: "desc" } }
        when "after"
          {order: { public_timestamp: "asc" } }
        else
          {}
        end
      else
        {}
      end
    end

    def filter_by_announcement_type
      if selected_announcement_type_option
        {search_format_types: selected_announcement_type_option.search_format_types}
      else
        {search_format_types: [Announcement.search_format_type]}
      end
    end

    def filter_by_publication_type
      if selected_publication_filter_option
        {search_format_types: selected_publication_filter_option.search_format_types}
      else
        {search_format_types: [Publication.search_format_type, StatisticalDataSet.search_format_type, Consultation.search_format_type]}
      end
    end

    def search_format_types_from_model_names(model_names)
      model_names.map do |model_name|
        Object.const_get(model_name).search_format_type
      end
    end

    def documents
      if @results.empty? || @results['results'].empty?
        @documents ||= Kaminari.paginate_array([]).page(@page).per(@per_page)
      else
        objects = Edition.includes(self.edition_eager_load).find(@results['results'].map{ |h| h["id"] })
        sorted = @results['results'].map do |doc|
          objects.detect { |obj| obj.id == doc['id'] }
        end

        @documents ||= Kaminari.paginate_array(sorted, total_count: @results['total']).page(@page).per(@per_page)
      end
    end

  end
end
