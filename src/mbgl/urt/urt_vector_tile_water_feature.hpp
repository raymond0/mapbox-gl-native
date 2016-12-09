//
//  urt_vector_tile_water_feature.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once

#import "urt_vector_tile_feature.hpp"

namespace mbgl {

using namespace std;
    
class UrtVectorTileWaterFeature : public UrtVectorTileFeature
{
public:
    UrtVectorTileWaterFeature( Region *region_ );
    virtual unique_ptr<GeometryTileFeature> clone() override;
    
    void addLandArea( MapItem *landArea, bool fromProxyTile );
    void addWaterAreas( vector<pair<MapItem *, bool> >::iterator first, vector<pair<MapItem *, bool> >::iterator last );
    
    FeatureType getType() const override;
    GeometryCollection getGeometries() const override;
    
private:
    vector<pair<MapItem *, bool> > landAreas;
    vector<pair<MapItem *, bool> > waterAreas;
};

}
