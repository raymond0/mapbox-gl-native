//
//  urt_tile_layer.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_tile_layer.hpp"
#include "urt_vector_tile_road_feature.hpp"
#include "urt_vector_tile_place_label_feature.hpp"
#include "urt_vector_tile_road_label_feature.hpp"
#include "urt_vector_tile_whole_area_feature.hpp"

namespace mbgl {

void UrtTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    auto feature = make_unique<UrtVectorTileFeature>(mapItem, region, fromProxyTile);
    features.emplace_back( move(feature) );
}


unique_ptr<GeometryTileFeature> UrtTileLayer::getFeature(std::size_t i) const
{
    return features.at(i)->clone();
}


string UrtTileLayer::getName() const
{
    return name;
}
    
    
void UrtTileLayer::setWholeGroundType( item_type _groundType )
{
    groundType = _groundType;
}
    
    
void UrtTileLayer::finalizeInternalItems()
{
    if ( groundType == type_whole_area_type_wood )
    {
        auto feature = make_unique<UrtVectorTileWholeAreaFeature>(region, groundType);
        features.emplace_back( move(feature) );
    }
}
    
    
void UrtRoadLabelTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    auto feature = make_unique<UrtVectorTileRoadLabelFeature>(mapItem, region, fromProxyTile);
    
    if ( feature->shouldRender() )
    {
        features.emplace_back( move(feature) );
    }
}
    
    
void UrtRoadTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    auto feature = make_unique<UrtVectorTileRoadFeature>(mapItem, region, fromProxyTile);
    features.emplace_back( move(feature) );
}

    
void UrtPlaceTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    auto feature = make_unique<UrtVectorTilePlaceLabelFeature>(mapItem, region, fromProxyTile);
    features.emplace_back( move(feature) );
}

}
