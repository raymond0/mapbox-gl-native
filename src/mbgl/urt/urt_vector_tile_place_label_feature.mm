//
//  urt_vector_tile_place_label_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_place_label_feature.hpp"

namespace mbgl {
    
    
UrtVectorTilePlaceLabelFeature::UrtVectorTilePlaceLabelFeature( MapItem *mapItem_, Region *region_, bool fromProxyTile_ )
    : mbgl::UrtVectorTileFeature(mapItem_, region_, fromProxyTile_)
{
    
}

    
unique_ptr<GeometryTileFeature> UrtVectorTilePlaceLabelFeature::clone()
{
    auto other = make_unique<UrtVectorTilePlaceLabelFeature>(mapItem, region, fromProxyTile);
    other->properties = GetMapboxTags();
    return move(other);
}
    
    
UrtVectorTileFeature::MapboxTagsPtr UrtVectorTilePlaceLabelFeature::GetMapboxTags() const
{
    auto labelType = [=]() -> string
    {
        switch ( mapItem.itemType )
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
    
    NSString *townLabelStr = [[mapItem attributeOfType: attr_town_name] stringForAttribute];
    const char *townLabel = townLabelStr.UTF8String;
    
    if ( townLabel != NULL )
    {
        mapboxTags->insert({"name", (string) townLabel});
        mapboxTags->insert({"name_en", (string) townLabel});
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
