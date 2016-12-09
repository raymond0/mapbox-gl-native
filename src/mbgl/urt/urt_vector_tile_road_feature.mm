//
//  urt_vector_tile_road_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_road_feature.hpp"

namespace mbgl {
    
    
UrtVectorTileRoadFeature::UrtVectorTileRoadFeature( MapItem *mapItem_, Region *region_, bool fromProxyTile_ )
    : UrtVectorTileFeature(mapItem_, region_, fromProxyTile_ )
{
    
}
    
    
unique_ptr<GeometryTileFeature> UrtVectorTileRoadFeature::clone()
{
    auto other = make_unique<UrtVectorTileRoadFeature>(mapItem, region, fromProxyTile);
    other->properties = GetMapboxTags();
    return move(other);
}
    
    
UrtVectorTileRoadFeature::MapboxTagsPtr UrtVectorTileRoadFeature::GetMapboxTags() const
{
    auto roadClassAndType = [=]() -> pair<string, string>
    {
        switch ( mapItem.itemType )
        {
            case type_street_nopass:        // ToDo - verify nopass
            case type_street_0:
                return pair<string, string>("street", "unclassified");
            case type_street_residential_city:
            case type_street_residential_land:
                return pair<string, string>("street", "residential");
            case type_street_tertiary_city:
            case type_street_tertiary_land:
                return pair<string, string>("tertiary", "tertiary");
            case type_ramp_tertiary:
                return pair<string, string>("link", "tertiary_link");
            case type_street_secondary_city:
            case type_street_secondary_land:
                return pair<string, string>("secondary", "secondary");
            case type_ramp_secondary:
                return pair<string, string>("link", "secondary_link");
            case type_street_primary_city:
            case type_street_primary_land:
                return pair<string, string>("primary", "primary");
            case type_ramp_primary:
                return pair<string, string>("link", "primary_link");
            case type_street_trunk:
            case type_roundabout:           // ToDo - Roundabout is trunk???
                return pair<string, string>("trunk", "trunk");
            case type_ramp_trunk:
                return pair<string, string>("link", "trunk_link");
            case type_highway_city:
            case type_street_motorway:
            case type_highway_land:
                return pair<string, string>("motorway", "motorway");
            case type_ramp_motorway:
                return pair<string, string>("motorway_link", "motorway_link");
            case type_living_street:
                return pair<string, string>("street", "living_street");
            case type_street_service:
                return pair<string, string>("service", "service");
            case type_street_parking_lane:
                return pair<string, string>("service", "service:parking_aisle");
            default:
                assert( false );
                return pair<string, string>("", "");
        }
    }();
    
    MapboxTagsPtr mapboxTags ( new MapboxTags );
    
    if ( roadClassAndType.first.length() > 0 )
    {
        mapboxTags->insert({"class", (string) roadClassAndType.first});
    }
    
    if ( roadClassAndType.second.length() > 0 )
    {
        mapboxTags->insert({"type", (string) roadClassAndType.second});
    }
    
    mapboxTags->insert({"oneway", (string) ( [mapItem oneWayType] != TwoWay ? "true" : "false" )});   // ToDo
    mapboxTags->insert({"structure", (string) "none"}); // ToDo
        
    return mapboxTags;
}

    
FeatureType UrtVectorTileRoadFeature::getType() const
{
    return FeatureType::LineString;
}
    

GeometryCollection UrtVectorTileRoadFeature::getGeometries() const
{
    auto coordinateRanges = RelevantCoordinateRangesInTileRect( mapItem );
    
    GeometryCollection lines;
    for ( auto range : coordinateRanges )
    {
        auto coords = GetMapboxCoordinatesInRange( mapItem, range );
        lines.emplace_back( coords );
    }
    
    return lines;
}
    
}
