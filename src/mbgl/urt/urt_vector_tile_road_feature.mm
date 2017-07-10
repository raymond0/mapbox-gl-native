//
//  urt_vector_tile_road_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_road_feature.hpp"

namespace mbgl {
    
    
UrtVectorTileRoadFeature::UrtVectorTileRoadFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ )
    : UrtVectorTileFeature(itemType_, region_, fromProxyTile_)
{
    
}
    
    
void UrtVectorTileRoadFeature::addMapItem( MapItem *mapItem )
{
    isOneway = [mapItem oneWayType] != TwoWay;
    geometryCollection = getGeometriesForMapItem(mapItem);
}


    
unique_ptr<GeometryTileFeature> UrtVectorTileRoadFeature::clone()
{
    auto other = unique_ptr<UrtVectorTileRoadFeature>(new UrtVectorTileRoadFeature(itemType, region, fromProxyTile));
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    other->isOneway = isOneway;
    return move(other);
}
    
    
UrtVectorTileRoadFeature::MapboxTagsPtr UrtVectorTileRoadFeature::CreateMapboxTags(unsigned int itemType, BOOL isOneway)
{
    auto roadClassAndType = [=]() -> pair<string, string>
    {
        switch ( itemType )
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
            case type_street_pedestrian:
                return pair<string, string>("pedestrian", "pedestrian");
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
    
    mapboxTags->insert({"oneway", (string) ( isOneway ? "true" : "false" )});   // ToDo
    mapboxTags->insert({"structure", (string) "none"}); // ToDo
    
    return mapboxTags;
}

    
    
UrtVectorTileRoadFeature::MapboxTagsPtr UrtVectorTileRoadFeature::GetMapboxTagsStatic(unsigned int itemType, BOOL isOneway)
{
    if ( isOneway )
    {
        switch ( itemType )
        {
            case type_street_nopass:        // ToDo - verify nopass
            case type_street_0:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_residential_city:
            case type_street_residential_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_tertiary_city:
            case type_street_tertiary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_tertiary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_secondary_city:
            case type_street_secondary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_secondary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_primary_city:
            case type_street_primary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_primary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_trunk:
            case type_roundabout:           // ToDo - Roundabout is trunk???
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_trunk:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_highway_city:
            case type_street_motorway:
            case type_highway_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_motorway:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_living_street:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_service:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_parking_lane:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_pedestrian:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            default:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
        }
    }
    else
    {
        switch ( itemType )
        {
            case type_street_nopass:        // ToDo - verify nopass
            case type_street_0:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_residential_city:
            case type_street_residential_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_tertiary_city:
            case type_street_tertiary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_tertiary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_secondary_city:
            case type_street_secondary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_secondary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_primary_city:
            case type_street_primary_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_primary:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_trunk:
            case type_roundabout:           // ToDo - Roundabout is trunk???
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_trunk:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_highway_city:
            case type_street_motorway:
            case type_highway_land:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_ramp_motorway:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_living_street:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_service:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_parking_lane:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            case type_street_pedestrian:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
            default:
            {
                static MapboxTagsPtr mapboxTags = CreateMapboxTags(itemType, isOneway);
                return mapboxTags;
            }
        }
    }
}

    
//
//  Profiler indicated that over 1/3 of the rendering time was going on the hashing creation + destuction
//  of these tags. Have moved to an inelegant but much faster static version for now.
//
UrtVectorTileRoadFeature::MapboxTagsPtr UrtVectorTileRoadFeature::GetMapboxTags() const
{
    return GetMapboxTagsStatic(itemType, isOneway);
}

    
FeatureType UrtVectorTileRoadFeature::getType() const
{
    return FeatureType::LineString;
}
    

GeometryCollection UrtVectorTileRoadFeature::getGeometriesForMapItem( MapItem *mapItem ) const
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
