//
//  urt_vector_tile_place_label_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_place_label_feature.hpp"

namespace mbgl {
    
    
UrtVectorTilePlaceLabelFeature::UrtVectorTilePlaceLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ )
    : UrtVectorTileFeature(itemType_, region_, fromProxyTile_)
{
    
}

    
void UrtVectorTilePlaceLabelFeature::addMapItem( MapItem *mapItem )
{
    NSString *townLabelStr = [[mapItem attributeOfType: attr_town_name] stringForAttribute];
    const char *townLabel = townLabelStr.UTF8String;
    
    if ( townLabel != nil )
    {
        townLabelString = townLabel;
    }
    
    population = [[mapItem attributeOfType:attr_population_int] intForAttribute];

    geometryCollection = getGeometriesForMapItem(mapItem);
}


unique_ptr<GeometryTileFeature> UrtVectorTilePlaceLabelFeature::clone()
{
    auto other = unique_ptr<UrtVectorTilePlaceLabelFeature>(new UrtVectorTilePlaceLabelFeature(itemType, region, fromProxyTile));
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    return move(other);
}
    
    
UrtVectorTileFeature::MapboxTagsPtr UrtVectorTilePlaceLabelFeature::GetMapboxTags() const
{
    auto labelType = [=]() -> string
    {
        switch ( itemType )
        {
            case type_place_city:
                return "city";
            case type_place_suburb:
                return "suburb";
            case type_place_quarter:
                return "quarter";
            case type_place_neighbourhood:
                return "neighbourhood";
            case type_place_town:
                return "town";
            case type_place_village:
                return "village";
            case type_place_hamlet:
                return "hamlet";
            case type_place_island:
                return "island";
            case type_place_islet:
                return "islet";
            case type_place_locality:
                return "locality";
            default:
                assert( false );
                return "";
        }
    }();
    
    MapboxTagsPtr mapboxTags ( new MapboxTags() );
    
    if ( labelType.length() > 0 )
    {
        mapboxTags->insert({"type", labelType});
    }
    
    if ( population > 5000000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 0});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    else if ( population > 2000000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 1});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    else if ( population > 1000000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 2});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    else if ( population > 500000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 3});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    else if ( population > 100000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 4});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    else if ( population > 20000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 5});
        mapboxTags->insert({"ldir", (string) "N"});
    }
    
    if ( townLabelString.length() > 0 )
    {
        mapboxTags->insert({"name", townLabelString});
        mapboxTags->insert({"name_en", townLabelString});
    }
    
    return mapboxTags;
}
    
    
FeatureType UrtVectorTilePlaceLabelFeature::getType() const
{
    return FeatureType::Point;
}
    
    
    
    
UrtVectorTileCountryLabelFeature::UrtVectorTileCountryLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ )
    : UrtVectorTileFeature(itemType_, region_, fromProxyTile_)
{
    
}

    
void UrtVectorTileCountryLabelFeature::addMapItem( MapItem *mapItem )
{
    NSString *labelStr = [[mapItem attributeOfType: attr_label] stringForAttribute];
    const char *label = labelStr.UTF8String;
    
    if ( label != nil )
    {
        labelString = label;
    }
    
    population = [[mapItem attributeOfType:attr_population_int] intForAttribute];

    geometryCollection = getGeometriesForMapItem(mapItem);
}


unique_ptr<GeometryTileFeature> UrtVectorTileCountryLabelFeature::clone()
{
    auto other = unique_ptr<UrtVectorTileCountryLabelFeature>(new UrtVectorTileCountryLabelFeature(itemType, region, fromProxyTile));
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    return move(other);
}
    
    
UrtVectorTileFeature::MapboxTagsPtr UrtVectorTileCountryLabelFeature::GetMapboxTags() const
{
    MapboxTagsPtr mapboxTags ( new MapboxTags() );
    
    mapboxTags->insert({"type", (string) "country"});
    
    if ( population > 5000000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 1});
    }
    else if ( population > 1000000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 2});
    }
    else if ( population > 250000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 3});
    }
    else if ( population > 50000 )
    {
        mapboxTags->insert({"scalerank", (int64_t) 4});
    }
    else
    {
        mapboxTags->insert({"scalerank", (int64_t) 5});
    }
    
    if ( labelString.length() > 0 )
    {
        mapboxTags->insert({"name", labelString});
        mapboxTags->insert({"name_en", labelString});
    }
        
    return mapboxTags;
}
    
    
FeatureType UrtVectorTileCountryLabelFeature::getType() const
{
    return FeatureType::Point;
}

    
}
