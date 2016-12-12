//
//  rayclipper.hpp
//  navit
//
//  Created by Ray Hunter on 18/11/2016.
//
//

#ifndef rayclipper_hpp
#define rayclipper_hpp

#include <stdio.h>
#include <vector>
#include <UrtFile/UrtFile.h>
    
namespace rayclipper {
    
/*struct coord {
    int x;
    int y;
};
*/
struct rect {struct coord l,h;};
typedef std::vector<struct coord> Polygon;

std::vector<Polygon> RayClipPolygon( const Polygon &inputPolygon, struct rect rect );

bool PointIsInsidePolygon(const Polygon &coords, const struct coord &point);
void CleanPolygon( const Polygon &inputPolygon, Polygon &outputPolygon );

}


#endif /* rayclipper_hpp */
