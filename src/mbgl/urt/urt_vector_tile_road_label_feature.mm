//
//  urt_vector_tile_road_label_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 12/12/2016.
//
//

#include "urt_vector_tile_road_label_feature.hpp"

namespace mbgl {
    
UrtVectorTileRoadLabelFeature::UrtVectorTileRoadLabelFeature( MapItem *mapItem_, Region *region_, bool fromProxyTile_ )
: mbgl::UrtVectorTileFeature(mapItem_, region_, fromProxyTile_)
{
    
}


unique_ptr<GeometryTileFeature> UrtVectorTileRoadLabelFeature::clone()
{
    auto other = make_unique<UrtVectorTileRoadLabelFeature>(mapItem, region, fromProxyTile);
    other->properties = GetMapboxTags();
    return move(other);
}

    
/*
    class = 0, 5, 13, 17, 22, 27
 street
 path
 service
 secondary
 tertiary
 ferry
*/

UrtVectorTileFeature::MapboxTagsPtr UrtVectorTileRoadLabelFeature::GetMapboxTags() const
{
    MapboxTagsPtr mapboxTags ( new MapboxTags );
    
    NSString *renderingString = [mapItem streetRenderingString];
    if ( renderingString == nil )
    {
        return mapboxTags;
    }

    //mapboxTags->insert({"iso_3166_2", (string) "NL-NH"});
    mapboxTags->insert({"len", (double) distanceOfLongestSection()});
    mapboxTags->insert({"name", (string) renderingString.UTF8String});
    mapboxTags->insert({"name_en", (string) renderingString.UTF8String});
    
    switch ( mapItem.itemType )
    {
        case type_street_nopass:        // ToDo - verify nopass
        case type_street_0:
            mapboxTags->insert({"class", (string) "street"});
            break;
        case type_street_residential_city:
        case type_street_residential_land:
            mapboxTags->insert({"class", (string) "street"});
            break;
        case type_street_tertiary_city:
        case type_street_tertiary_land:
            mapboxTags->insert({"class", (string) "tertiary"});
            break;
        case type_ramp_tertiary:
            mapboxTags->insert({"class", (string) "tertiary_link"});
            break;
        case type_street_secondary_city:
        case type_street_secondary_land:
            mapboxTags->insert({"class", (string) "secondary"});
            break;
        case type_ramp_secondary:
            mapboxTags->insert({"class", (string) "secondary_link"});
            break;
        case type_street_primary_city:
        case type_street_primary_land:
            mapboxTags->insert({"class", (string) "primary"});
            break;
        case type_ramp_primary:
            mapboxTags->insert({"class", (string) "primary_link"});
            break;
        case type_street_trunk:
        case type_roundabout:           // ToDo - Roundabout is trunk???
            mapboxTags->insert({"class", (string) "trunk"});
            break;
        case type_ramp_trunk:
            mapboxTags->insert({"class", (string) "trunk_link"});
            break;
        case type_highway_city:
        case type_street_motorway:
        case type_highway_land:
            mapboxTags->insert({"class", (string) "motorway"});
            break;
        case type_ramp_motorway:
            mapboxTags->insert({"class", (string) "motorway_link"});
            break;
        case type_living_street:
            mapboxTags->insert({"class", (string) "street"});
            break;
        case type_street_service:
        case type_street_parking_lane:
            mapboxTags->insert({"class", (string) "service"});
            break;
        case type_street_pedestrian:
            mapboxTags->insert({"class", (string) "pedestrian"});
            break;
        default:
            assert( false );
            return mapboxTags;
    }
        
    return mapboxTags;
}


FeatureType UrtVectorTileRoadLabelFeature::getType() const
{
    return FeatureType::LineString;
}
    
    
GeometryCollection UrtVectorTileRoadLabelFeature::getGeometries() const
{
    GeometryCollection lines;
    auto ls = longestSection();
    
    auto coords = GetMapboxCoordinatesInRange( mapItem, ls );
    lines.emplace_back( coords );
    
    return lines;
}
    
    
double UrtVectorTileRoadLabelFeature::distanceOfLongestSection() const
{
    auto ls = longestSection();
    if ( ls.second == 0 )
    {
        return 0;
    }
    
    return distanceOfSection(ls);
}
    
    
UrtVectorTileFeature::CoordRange UrtVectorTileRoadLabelFeature::longestSection() const
{
    auto coordinateRanges = RelevantCoordinateRangesInTileRect( mapItem );
    
    if ( coordinateRanges.size() == 0 )
    {
        return CoordRange(0, 0);
    }

    double longestDistance = 0;
    size_t longestIndex = 0;
    
    for ( size_t i = 0; i < coordinateRanges.size(); i++ )
    {
        auto range = coordinateRanges[i];
        double d = distanceOfSection(range);
        if ( d > longestDistance )
        {
            longestDistance = d;
            longestIndex = i;
        }
    }
    
    return coordinateRanges[longestIndex];
}
    
    
double UrtVectorTileRoadLabelFeature::distanceOfSection(UrtVectorTileFeature::CoordRange &section) const
{
    coord *coords;
    uint32_t nrCoords = (uint32_t) [mapItem lengthOfCoordinatesWithData:&coords];

    assert ( nrCoords >= section.first + section.second );
    assert( section.second > 1 );
    
    double distance = 0;
    
    for ( uint32_t i = 0; i < section.second - 1; i++ )
    {
        distance += LengthBetweenCoords( coords[i], coords[i + 1] );
    }
    
    return distance;
}
    
    
bool UrtVectorTileRoadLabelFeature::shouldRender()
{
    if ( [mapItem streetRenderingString] == nil )
    {
        return false;
    }
    
    coord *coords;
    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:&coords];

    assert( nrCoords > 0 );
    
    Region *itemRegion;
    
    for ( NSInteger i = 0; i < nrCoords; i++ )
    {
        Coordinate *c = [[Coordinate alloc] initWithCoord:coords[i]];

        if ( i == 0 )
        {
            itemRegion = [[Region alloc] initWithMinimum:c maximum:c];
        }
        else
        {
            [itemRegion expandWithCoordinate:c];
        }
    }
    
    return [region containsCoordinate:itemRegion.centre];
}

}
