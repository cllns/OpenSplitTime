class LocationSerializer < ActiveModel::Serializer
  attributes :id, :name, :latitude, :longitude, :elevation
end