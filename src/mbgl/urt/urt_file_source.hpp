//
//  urt_file_source.hpp
//  mbgl
//
//  Created by Ray Hunter on 16/11/2016.
//
//

#pragma once

#include <mbgl/storage/file_source.hpp>

namespace mbgl {
    
    class URTFileSource : public FileSource {
    public:
        URTFileSource();
        ~URTFileSource() override;
        
        std::unique_ptr<AsyncRequest> request(const Resource&, Callback) override;
        
        static bool usingUrtSource;

    private:
        class Impl;
        std::unique_ptr<Impl> impl;
    };
    
} // namespace mbgl
