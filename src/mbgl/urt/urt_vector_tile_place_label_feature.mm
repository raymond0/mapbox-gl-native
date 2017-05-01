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
        mapboxTags->insert({"type", (string) labelType});
    }
    
    if ( townLabelString.length() > 0 )
    {
        mapboxTags->insert({"name", townLabelString});
        mapboxTags->insert({"name_en", townLabelString});
    }
    
    //mapboxTags.emplace_back("ldir", (string) "N");
    //mapboxTags.emplace_back("localrank", (uint64_t) 1);
    //mapboxTags.emplace_back("scalerank", (uint64_t) 1);
    
    return mapboxTags;
}
    
    
FeatureType UrtVectorTilePlaceLabelFeature::getType() const
{
    return FeatureType::Point;
}

    
}
