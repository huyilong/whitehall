# A bunch of helpers for efficiently generating select options for taggable
# content, e.g. topics, organisations, etc.
module Admin::TaggableContentHelper

  # Returns an Array that represents the current set of taggable topics.
  # Each element of the array consists of two values: the name and ID of the
  # topic.
  def taggable_topics_container
    Rails.cache.fetch(taggable_topics_cache_digest) do
      Topic.order(:name).map { |t| [t.name, t.id] }
    end
  end

  # Returns an Array that represents the current set of taggable topical
  # events. Each element of the array consists of two values: the name and ID
  # of the topical event.
  def taggable_topical_events_container
    Rails.cache.fetch(taggable_topical_events_cache_digest) do
      TopicalEvent.order(:name).map { |te| [te.name, te.id] }
    end
  end

  # Returns an Array that represents the current set of taggable organisations.
  # Each element of the array consists of two values: the select_name and the
  # ID of the organisation
  def taggable_organisations_container
    Rails.cache.fetch(taggable_organisations_cache_digest) do
      Organisation.with_translations.order(:name).map { |o| [o.select_name, o.id] }
    end
  end

  # Returns an Array that represents the current set of taggable ministerial
  # roles (both past and present). Each element of the array consists fo two
  # values: a selectable label (consisting of the person, the role, the date
  # the role was held if it's in the past, and the organisations the person
  # belongs to) and the ID of the role appointment.
  def taggable_ministerial_role_appointments_container
    Rails.cache.fetch(taggable_ministerial_role_appointments_cache_digest) do
      RoleAppointment.for_ministerial_roles.
                      includes(:person).
                      with_translations_for(:organisations).
                      with_translations_for(:role).
                      alphabetical_by_person.map do |appointment|
        [ministerial_role_appointment_label(appointment), appointment.id]
      end
    end
  end

  # Returns an MD5 digest representing the current set of taggable topics. This
  # will change if any of the Topics should change or if a new topic is added.
  def taggable_topics_cache_digest
    update_timestamps = Topic.order(:id).pluck(:updated_at).map(&:to_i).join
    Digest::MD5.hexdigest "taggable-topics-#{update_timestamps}"
  end

  # Returns an MD5 digest representing the current set of taggable topical
  # events. This will change if any of the Topics should change or if a new
  # topic event is added.
  def taggable_topical_events_cache_digest
    update_timestamps = TopicalEvent.order(:id).pluck(:updated_at).map(&:to_i).join
    Digest::MD5.hexdigest "taggable-topical-events-#{update_timestamps}"
  end

  # Returns an MD5 digest representing the current set of taggable
  # organisations. This will change if any of the Topics should change or if a
  # new organisation is added.
  def taggable_organisations_cache_digest
    @taggable_organisations_cache_digest ||= begin
      update_timestamps = Organisation.order(:id).pluck(:updated_at).map(&:to_i).join
      Digest::MD5.hexdigest "taggable-organisations-#{update_timestamps}"
    end
  end

  # Returns an MD5 digest representing the current set of taggable ministerial
  # role appointments. This will change if any role appointments are added or
  # changed, and also if an occupied MinisterialRole is updated.
  def taggable_ministerial_role_appointments_cache_digest
    update_timestamps = RoleAppointment.order(:id).pluck(:updated_at).map(&:to_i).join
    Digest::MD5.hexdigest "taggable-ministerial-role-appointments-#{update_timestamps}"
  end

  # Note: Taken from Rails 4
  def cache_if(condition, name = {}, options = nil, &block)
    if condition
      cache(name, options, &block)
    else
      yield
    end

    nil
  end

private

  def ministerial_role_appointment_label(appointment)
    organisations = appointment.organisations.map(&:name).to_sentence
    person        = appointment.person.name
    role          = appointment.role.name
    unless appointment.current?
      role << " (#{l(appointment.started_at.to_date)} to #{l(appointment.ended_at.to_date)})"
    end

    [person, role, organisations].join(', ')
  end
end
