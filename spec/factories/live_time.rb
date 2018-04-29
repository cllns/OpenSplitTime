FactoryBot.define do
  factory :live_time do
    event
    split
    bitkey 1
    sequence(:bib_number, '101')
    absolute_time '08:00:00'
    source 'ost-test'

    after(:build, :stub) do |live_time|
      live_time.send(:create_sortable_bib_number)
    end
  end
end
