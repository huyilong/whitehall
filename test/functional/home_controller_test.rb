require "test_helper"

class HomeControllerTest < ActionController::TestCase
  include ActionDispatch::Routing::UrlFor
  include PublicDocumentRoutesHelper
  default_url_options[:host] = 'test.host'

  should_be_a_public_facing_controller

  view_test 'Atom feed has the right elements' do
    document = create(:published_news_article)

    get :feed, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > id', 1
      assert_select 'feed > title', 1
      assert_select 'feed > author, feed > entry > author'
      assert_select 'feed > updated', 1
      assert_select 'feed > link[rel=?][type=?][href=?]', 'self', 'application/atom+xml', atom_feed_url(format: :atom), 1
      assert_select 'feed > link[rel=?][type=?][href=?]', 'alternate', 'text/html', root_url, 1

      assert_select_atom_entries([document])
    end
  end

  view_test 'Atom feed shows a list of recently published documents' do
    create_published_documents
    draft_documents = create_draft_documents

    get :feed, format: :atom

    documents = Edition.published.in_reverse_chronological_order
    recent_documents = documents[0...10]
    older_documents = documents[10..-1]

    assert_select_atom_feed do
      assert_select 'feed > updated', text: recent_documents.first.public_timestamp.iso8601

      assert_select_atom_entries(recent_documents)
    end
  end

  view_test 'Atom feed shows a list of recently published documents with govdelivery attributes when requested' do
    editor = create(:departmental_editor)
    edition = create(:published_speech)
    version_2 = edition.create_draft(editor)
    version_2.change_note = 'My new version'
    version_2.publish_as(editor, force: true)

    get :feed, format: :atom, govdelivery_version: 'yes'

    assert_select_atom_feed do
      assert_select_atom_entries([version_2], true)
    end
  end

  view_test "home page doesn't link to itself in the progress bar" do
    get :home

    refute_select ".progress-bar a[href=#{root_path}]"
  end

  view_test "non home page doesn't link to itself in the progress bar" do
    get :how_government_works

    assert_select ".progress-bar a[href=#{root_path}]"
  end

  view_test "progress bar has current number of live departments" do
    org = create(:ministerial_department, govuk_status: 'live')
    org = create(:ministerial_department, govuk_status: 'transitioning')

    get :home

    assert_select '.progress-bar', /1 of 2/
  end

  view_test "how government works page shows a count of published policies" do
    create(:published_policy)
    create(:draft_policy)

    get :how_government_works

    assert_equal 1, assigns[:policy_count]
    assert_select ".policy-count .count", "1"
  end

  view_test "home page shows a count of live ministerial departmernts" do
    create(:ministerial_department, govuk_status: 'live')

    get :home

    assert_select '.live-ministerial-departments', '1'
  end

  view_test "home page shows a count of live non-ministerial departmernts" do
    # need to have the ministerial and suborg type so we can select non-ministerial
    create(:ministerial_organisation_type)
    create(:sub_organisation_type)

    type = create(:non_ministerial_organisation_type)
    org = create(:organisation, govuk_status: 'live', organisation_type: type)
    sub_org = create(:sub_organisation, govuk_status: 'live', parent_organisations: [create(:ministerial_department)])

    get :home

    assert_select '.live-other-departments', '1'
  end

  view_test "home page lists coming soon ministerial departments" do
    department = create(:ministerial_department, govuk_status: 'transitioning')

    get :home

    assert_select '.departments .coming-soon p', /#{department.name}/
  end

  view_test "home page lists coming soon non-ministerial departments" do
    create(:ministerial_organisation_type)
    create(:sub_organisation_type)

    type = create(:non_ministerial_organisation_type)
    department = create(:organisation, govuk_status: 'transitioning', organisation_type: type)

    get :home

    assert_select '.agencies .coming-soon p', /#{department.name}/
  end

  view_test "home page does not list transitioning sub-orgs" do
    create(:ministerial_organisation_type)
    create(:sub_organisation_type)

    department = create(:sub_organisation, govuk_status: 'transitioning')

    get :home

    refute_select '.agencies .coming-soon p', text: /#{department.name}/
  end

  test "home page lists topics with policies and topical events sorted alphabetically" do
    topics = [[0, 'alpha'], [1, 'juliet'], [2, 'echo']].map { |n, name| create(:topic, published_policies_count: n, name: name) }
    topical_event = create(:topical_event, name: 'foxtrot')

    get :home

    assert_equal [ topics[2], topical_event, topics[1]], assigns(:classifications)
  end

  private

  def create_published_documents
    2.downto(1) do |x|
      create(:published_policy, first_published_at: x.days.ago + 1.hour)
      create(:published_news_article, first_published_at: x.days.ago + 2.hours)
      create(:published_speech, delivered_on: x.days.ago + 3.hours)
      create(:published_publication, publication_date: x.days.ago + 4.hours)
      create(:published_consultation, opening_on: x.days.ago + 5.hours)
    end
  end

  def create_draft_documents
    [
      create(:draft_policy),
      create(:draft_news_article),
      create(:draft_speech),
      create(:draft_consultation),
      create(:draft_publication)
    ]
  end
end
