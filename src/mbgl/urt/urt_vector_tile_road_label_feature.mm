//
//  urt_vector_tile_road_label_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 12/12/2016.
//
//

#include "urt_vector_tile_road_label_feature.hpp"

namespace mbgl {
        
    
UrtVectorTileRoadLabelFeature::UrtVectorTileRoadLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ )
    : UrtVectorTileFeature(itemType_, region_, fromProxyTile_)
{
    
}
    
    
void UrtVectorTileRoadLabelFeature::addMapItem( MapItem *mapItem )
{
    NSString *renderingString = [mapItem streetRenderingString];
    if ( renderingString == nil )
    {
        return;
    }
    
    roadLabelString = renderingString.UTF8String;
    longestSectionDistance = distanceOfLongestSection( mapItem );
    
    geometryCollection = getGeometriesForMapItem(mapItem);
}

    

unique_ptr<GeometryTileFeature> UrtVectorTileRoadLabelFeature::clone()
{
    auto other = unique_ptr<UrtVectorTileRoadLabelFeature>( new UrtVectorTileRoadLabelFeature(itemType, region, fromProxyTile) );
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    other->roadLabelString = roadLabelString;
    other->longestSectionDistance = longestSectionDistance;
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
    
    if ( roadLabelString.length() == 0 )
    {
        return mapboxTags;
    }

    //mapboxTags->insert({"iso_3166_2", (string) "NL-NH"});
    mapboxTags->insert({"len", longestSectionDistance});
    mapboxTags->insert({"name", roadLabelString});
    mapboxTags->insert({"name_en", roadLabelString});
    
    switch ( itemType )
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
    
    
GeometryCollection UrtVectorTileRoadLabelFeature::getGeometriesForMapItem( MapItem *mapItem ) const
{
    GeometryCollection lines;
    auto ls = longestSection( mapItem );
    
    auto coords = GetMapboxCoordinatesInRange( mapItem, ls );
    lines.emplace_back( coords );
    
    return lines;
}
    
    
double UrtVectorTileRoadLabelFeature::distanceOfLongestSection(MapItem *mapItem) const
{
    auto ls = longestSection( mapItem );
    if ( ls.length == 0 )
    {
        return 0;
    }
    
    return distanceOfSection(mapItem, ls);
}
    
    
UrtVectorTileFeature::CoordRange UrtVectorTileRoadLabelFeature::longestSection(MapItem *mapItem) const
{
    auto coordinateRanges = RelevantCoordinateRangesInTileRect( mapItem );
    
    if ( coordinateRanges.size() == 0 )
    {
        return CoordRange(0, 0, UrtVectorTileFeature::CoordRange::Empty);
    }

    double longestDistance = 0;
    size_t longestIndex = 0;
    
    for ( size_t i = 0; i < coordinateRanges.size(); i++ )
    {
        auto range = coordinateRanges[i];
        
        if ( range.length < 2 )
        {
            continue;
        }
        
        double d = distanceOfSection(mapItem, range);
        if ( d > longestDistance )
        {
            longestDistance = d;
            longestIndex = i;
        }
    }
    
    if ( coordinateRanges[longestIndex].length < 2 )
    {
        return CoordRange(0, 0, UrtVectorTileFeature::CoordRange::Empty);
    }

    return coordinateRanges[longestIndex];
}
    
    
double UrtVectorTileRoadLabelFeature::distanceOfSection(MapItem *mapItem, UrtVectorTileFeature::CoordRange &section) const
{
    coord *coords;
    NSInteger nrCoords __unused = [mapItem lengthOfCoordinatesWithData:&coords];

    assert ( nrCoords >= section.index + section.length );
    assert( section.length > 1 );
    
    double distance = 0;
    
    for ( NSInteger i = 0; i < section.length - 1; i++ )
    {
        distance += LengthBetweenCoords( coords[i], coords[i + 1] );
    }
    
    return distance;
}
    
    
bool UrtVectorTileRoadLabelFeature::shouldRender( MapItem *mapItem )
{
    if ( roadLabelString.length() == 0 )
    {
        return false;
    }
    
    if ( longestSectionDistance < DBL_EPSILON )
    {
        return false;
    }
    
    coord *coords;
    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:&coords];

    assert( nrCoords > 0 );
    
    URRegion itemRegion = { coords[0], coords[0] };
    
    for ( NSInteger i = 1; i < nrCoords; i++ )
    {
        URRegionExpand( itemRegion, coords[i] );
    }
    
    coord itemCenter = URRegionCenter(itemRegion);
    
    if ( ! URRegionContainsCoord(region, itemCenter) )
    {
        return false;
    }
    
    return true;
}

}
