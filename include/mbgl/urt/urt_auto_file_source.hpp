//
//  UrtAutoFileSource.hpp
//  ios
//
//  Created by Ray Hunter on 27/03/2017.
//  Copyright © 2017 Mapbox. All rights reserved.
//

#pragma once

#include <mbgl/storage/file_source.hpp>
#include "urt_file_source.hpp"
#include <mbgl/storage/default_file_source.hpp>

@class MGLReachability;

namespace mbgl {
    
    class URTAutoFileSource : public FileSource {
    public:
        URTAutoFileSource();
        ~URTAutoFileSource() override;
        
        std::unique_ptr<AsyncRequest> request(const Resource&, Callback) override;
        
    private:
        DefaultFileSource *m_default_file_source;
        URTFileSource *m_urt_file_source;
        bool m_online;
        MGLReachability *reach;
    };
    
} // namespace mbgl
