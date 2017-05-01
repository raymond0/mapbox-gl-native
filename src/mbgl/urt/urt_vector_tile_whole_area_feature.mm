//
//  urt_vector_tile_whole_area_feature.cpp
//  
//
//  Created by Ray Hunter on 04/04/2017.
//
//

#include "urt_vector_tile_whole_area_feature.hpp"
#import <mbgl/util/constants.hpp>

namespace mbgl {
    
UrtVectorTileWholeAreaFeature::UrtVectorTileWholeAreaFeature( URRegion region_, item_type _itemType )
: mbgl::UrtVectorTileFeature( 0, region_, false ), itemType(_itemType)
{

}
    
    
unique_ptr<GeometryTileFeature> UrtVectorTileWholeAreaFeature::clone()
{
    auto other = make_unique<UrtVectorTileWholeAreaFeature>( region, itemType );
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    return move(other);
}
    
    
UrtVectorTileFeature::MapboxTagsPtr UrtVectorTileWholeAreaFeature::GetMapboxTags() const
{
    auto classAndType = [=]() -> pair<string, string>
    {
        switch ( itemType )
        {
            case type_whole_area_type_wood:
                return pair<string, string>("park", "garden");
            default:
                assert( false );
                return pair<string, string>("", "");
        }
    }();
    
    MapboxTagsPtr mapboxTags( new MapboxTags() );
    
    if ( classAndType.first.length() > 0 )
    {
        mapboxTags->insert({"class", (string) classAndType.first});
    }
    
    if ( classAndType.second.length() > 0 )
    {
        mapboxTags->insert({"type", (string) classAndType.second});
    }
    
    return mapboxTags;
}


FeatureType UrtVectorTileWholeAreaFeature::getType() const
{
    return FeatureType::Polygon;
}



GeometryCollection UrtVectorTileWholeAreaFeature::getGeometries() const
{
    GeometryCollection lines;
    
    //
    //  Add a border of 1 all around the edge. Tangent edges on valid polygons *sometimes* blow
    //  something up further down the line without this, and invalidate all land areas.
    //  Docs do state we need to avoid tanget edges.
    //
    GeometryCoordinates line;
    line.emplace_back( GeometryCoordinate(0 ,0) );
    line.emplace_back( GeometryCoordinate(0,util::EXTENT) );
    line.emplace_back( GeometryCoordinate(util::EXTENT, util::EXTENT) );
    line.emplace_back( GeometryCoordinate(util::EXTENT, 0) );
    
    lines.emplace_back( line );
    return lines;
}

}
