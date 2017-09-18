require 'rails_helper'

describe Api::V1::StagingController do
  let(:event_group) { create(:event_group, organization: organization) }
  let(:event) { create(:event, event_group: event_group, course: course) }
  let(:course) { create(:course) }
  let(:organization) { create(:organization) }
  let(:event_id) { event.to_param }
  let(:new_event_indicator) { 'new' }

  login_admin

  describe '#get_countries' do
    it 'returns a successful 200 response' do
      get :get_countries
      expect(response).to be_success
    end

    it 'returns a set of country data that includes all Carmen countries' do
      country_count = Carmen::Country.all.size
      get :get_countries
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['countries'].size).to eq(country_count)
    end

    it 'returns subregions for each country that include all Carmen subregions for that country' do
      us = Carmen::Country.coded('US')
      subregion_count = us.subregions.reject { |subregion| subregion.type == 'apo' }.size
      get :get_countries
      parsed_response = JSON.parse(response.body)
      us_subregions = parsed_response['countries'].find { |country| country['code'] == 'US' }['subregions']
      expect(us_subregions.size).to eq(subregion_count)
    end
  end

  describe '#get_time_zones' do
    it 'returns a successful 200 response' do
      get :get_time_zones
      expect(response).to be_success
    end

    it 'returns an array of all ActiveSupport::TimeZone names and offsets' do
      tz_count = ActiveSupport::TimeZone.all.size
      get :get_time_zones
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['time_zones'].size).to eq(tz_count)
    end

    it 'returns both names and formatted offsets for each time zone' do
      eastern_time_zone_name = 'Eastern Time (US & Canada)'
      eastern = ActiveSupport::TimeZone[eastern_time_zone_name]
      get :get_time_zones
      parsed_response = JSON.parse(response.body)
      eastern_response = parsed_response['time_zones'].find { |tz| tz.first == eastern_time_zone_name }
      expect(eastern_response.last).to eq(eastern.formatted_offset)
    end
  end

  describe '#post_event_course_org' do
    let(:course_params) { course.attributes.with_indifferent_access.slice(*CourseParameters.permitted) }
    let(:organization_params) { organization.attributes.with_indifferent_access.slice(*OrganizationParameters.permitted) }

    context 'when an existing event_id is provided' do
      let(:event_params) { event.attributes.with_indifferent_access.slice(*EventParameters.permitted) }

      it 'returns a successful 200 response' do
        params = {event: event_params,
                  course: course_params,
                  organization: organization_params}
        expected_response = 200
        expected_attributes = {}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'updates provided attributes for an existing organization' do
        new_params = {name: 'Updated Organization Name', description: 'Updated organization description'}
        params = {event: event_params,
                  course: course_params,
                  organization: organization_params.merge(new_params)}
        expected_response = 200
        expected_attributes = {organization: [:name, :description]}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'updates provided attributes for an existing course' do
        new_params = {name: 'Updated Course Name', description: 'Updated course description'}
        params = {event: event_params,
                  course: course_params.merge(new_params),
                  organization: organization_params}
        expected_response = 200
        expected_attributes = {course: [:name, :description]}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'updates provided attributes for an existing event' do
        new_params = {name: 'Updated Event Name', laps_required: 3}
        params = {event: event_params.merge(new_params),
                  course: course_params,
                  organization: organization_params}
        expected_response = 200
        expected_attributes = {event: [:name, :laps_required]}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end
    end

    context 'when a new event_id is provided' do
      let(:new_event_params) { {name: 'New Event Name', start_time: '2017-03-01 06:00:00', laps_required: 1, home_time_zone: 'Pacific Time (US & Canada)'} }
      let(:new_course_params) { {name: 'New Course Name', description: 'New course description.'} }
      let(:new_organization_params) { {name: 'New Organization Name'} }

      it 'returns a successful 200 response' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params,
                  organization: new_organization_params}
        expected_response = 200
        expected_attributes = {}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'creates an event using provided parameters and associates existing course and organization' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: course_params,
                  organization: organization_params}
        expected_response = 200
        expected_attributes = {event: [:name, :laps_required]}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'creates an event using provided parameters and associates newly created course and organization' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params,
                  organization: new_organization_params}
        expected_response = 200
        expected_attributes = {event: [:name, :laps_required]}
        post_and_validate_response(event_id, params, expected_response, expected_attributes)
      end

      it 'returns a bad request message with descriptive errors and provided data if the event cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params.except(:start_time),
                  course: new_course_params,
                  organization: new_organization_params}
        expected_response = 422
        expected_errors = [/Start time can't be blank/]
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
      end

      it 'returns a bad request message with descriptive errors and provided data if the course cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params.except(:name),
                  organization: new_organization_params}
        expected_response = 422
        expected_errors = [/Name can't be blank/]
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
      end

      it 'returns a bad request message with descriptive errors and provided data if the organization cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params,
                  organization: new_organization_params.except(:name)}
        expected_response = 422
        expected_errors = [/Name can't be blank/]
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
      end

      it 'does not create any resources if the organization cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params,
                  organization: new_organization_params.except(:name)}
        expected_response = 422
        expected_errors = []
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
        expect(Event.all.size).to eq(0)
        expect(Course.all.size).to eq(0)
        expect(Organization.all.size).to eq(0)
      end

      it 'does not create any resources if the course cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params,
                  course: new_course_params.except(:name),
                  organization: new_organization_params}
        expected_response = 422
        expected_errors = {}
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
        expect(Event.all.size).to eq(0)
        expect(Course.all.size).to eq(0)
        expect(Organization.all.size).to eq(0)
      end

      it 'does not create any resources if the event cannot be created' do
        event_id = new_event_indicator
        params = {event: new_event_params.except(:start_time),
                  course: new_course_params,
                  organization: new_organization_params}
        expected_response = 422
        expected_errors = {}
        post_and_validate_errors(event_id, params, expected_response, expected_errors)
        expect(Event.all.size).to eq(0)
        expect(Course.all.size).to eq(0)
        expect(Organization.all.size).to eq(0)
      end
    end

    def post_and_validate_response(event_id, params, expected_response, expected_attributes)
      post :post_event_course_org, params: {staging_id: event_id,
                                            event: params[:event],
                                            course: params[:course],
                                            organization: params[:organization]}

      parsed_response = JSON.parse(response.body)
      resources = {event: Event.find_by(id: parsed_response['event']['id']),
                   event_group: EventGroup.find_by(id: parsed_response['event_group']['id']),
                   course: Course.find_by(id: parsed_response['course']['id']),
                   organization: Organization.find_by(id: parsed_response['organization']['id'])}

      expect(response.status).to eq(expected_response)

      event = resources[:event]
      event_group = resources[:event_group]
      course = resources[:course]
      organization = resources[:organization]

      expect(event.event_group_id).to eq(event_group.id)
      expect(event.course_id).to eq(course.id)
      expect(event_group.organization_id).to eq(organization.id)

      expected_attributes.each do |class_name, attributes|
        attributes.each do |attribute|
          expect(resources[class_name].attributes.with_indifferent_access[attribute])
              .to eq(params[class_name][attribute])
        end
      end
    end

    def post_and_validate_errors(event_id, params, expected_response, expected_errors)
      post :post_event_course_org, params: {staging_id: event_id,
                                            event: params[:event],
                                            course: params[:course],
                                            organization: params[:organization]}

      expect(response.status).to eq(expected_response)

      parsed_response = JSON.parse(response.body)
      message_array = parsed_response['errors'].map { |error| error['detail']['messages'] }.flatten

      expected_errors.each do |error_text|
        expect(message_array).to include(error_text)
      end
    end
  end

  describe '#update_event_visibility' do
    context 'when params[:status] == "public"' do
      let(:status) { 'public' }

      it 'returns a successful 200 response' do
        patch :update_event_visibility, params: {staging_id: event.to_param, status: status}
        expect(response).to be_success
      end

      it 'sets concealed status of the event_group, organization, and people to false' do
        event_group.update(concealed: true)
        organization.update(concealed: true)
        efforts = create_list(:effort, 3, event: event)
        efforts.each { |effort| effort.person.update(concealed: true) }

        patch :update_event_visibility, params: {staging_id: event.to_param, status: status}

        event_group.reload
        organization.reload
        expect(event_group.concealed).to eq(false)
        expect(organization.concealed).to eq(false)
        event.efforts.each do |effort|
          expect(effort.person.concealed).to eq(false)
        end
      end
    end

    context 'when params[:status] == "private"' do
      let(:status) { 'private' }

      it 'returns a successful 200 response' do
        patch :update_event_visibility, params: {staging_id: event.to_param, status: status}
        expect(response).to be_success
      end

      it 'sets concealed status of the event_group and its related organization and people to true' do
        event_group.update(concealed: false)
        organization.update(concealed: false)
        efforts = create_list(:effort, 3, event: event)
        efforts.each { |effort| effort.person.update(concealed: false) }

        patch :update_event_visibility, params: {staging_id: event.to_param, status: status}

        event_group.reload
        organization.reload
        expect(event_group.concealed).to eq(true)
        expect(organization.concealed).to eq(true)
        event.efforts.each do |effort|
          expect(effort.person.concealed).to eq(true)
        end
      end

      it 'does not make a person private if that person has other public efforts' do
        event.update(concealed: false)
        organization.update(concealed: false)
        efforts = create_list(:effort, 3, event: event)
        efforts.each { |effort| effort.person.update(concealed: false) }
        p_with_other_effort = efforts.first.person
        create(:effort, person: p_with_other_effort)
        patch :update_event_visibility, params: {staging_id: event.to_param, status: status}
        event.reload
        organization.reload
        expect(event.concealed).to eq(true)
        expect(organization.concealed).to eq(true)
        event.efforts.each do |effort|
          person = effort.person
          if person == p_with_other_effort
            expect(effort.person.concealed).to eq(false)
          else
            expect(effort.person.concealed).to eq(true)
          end
        end
      end
    end

    context 'when params[:status] is not "public" or "private"' do
      it 'returns a bad request response' do
        patch :update_event_visibility, params: {staging_id: event.to_param, status: 'random'}
        expect(response).to be_bad_request
      end
    end

    context 'when the event_id does not exist' do
      it 'returns a not found response' do
        patch :update_event_visibility, params: {staging_id: 123, status: 'public'}
        expect(response).to be_not_found
      end
    end
  end
end
