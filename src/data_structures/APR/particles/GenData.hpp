//
// Created by cheesema on 2019-06-10.
//

#ifndef LIBAPR_GENDATA_HPP
#define LIBAPR_GENDATA_HPP

#include "data_structures/Mesh/PixelData.hpp"
#include "../iterators/LinearIterator.hpp"
#include "../APR.hpp"
#include "numerics/APRCompress.hpp"

template<typename DataType>
class GenData {

private:
    DataType temp1 = 0;
    uint64_t temp2 = 0;

public:

    APRCompress compressor;


    /*
     * Virtual functions to be over-written by the derived class.
     */
     void init(APR& apr,unsigned int level){
        // must be implimented
    };

     void init_tree(APR& apr,unsigned int level){
        // must be implimented
    };

     void init(APR& apr){
        // must be implimented
    };

     void init_tree(APR& apr){
        // must be implimented
    };


    virtual void set_to_zero(){
        //must be implimented
    }




private:


};

//template<typename datasetType,typename iteratorType>
//void gen_fill_level(APR& apr,datasetType& data,iteratorType& it,bool tree){
//
//    if(tree){
//        data.init_tree(apr);
//    } else {
//        data.init(apr);
//    }
//
//    for (unsigned int level = it.level_min(); level <= it.level_max(); ++level) {
//#ifdef HAVE_OPENMP
//#pragma omp parallel for schedule(dynamic) firstprivate(it)
//#endif
//        for (int z = 0; z < it.z_num(level); ++z) {
//            for (int x = 0; x < it.x_num(level); ++x) {
//                for (it.begin(level, z, x);it <it.end();it++) {
//
//                    data[it] = level;
//                }
//            }
//        }
//    }
//}



///**
//* Samples particles from an image using by down-sampling the image and using them as functions
//*/
//template<typename U>
//void sample_parts_from_img_downsampled(APR& apr,PixelData<U>& input_image) {
//
//    std::vector<PixelData<U>> downsampled_img;
//    //Down-sample the image for particle intensity estimation
//    downsamplePyrmaid(input_image, downsampled_img, apr.level_max(), apr.level_min());
//
//    //aAPR.get_parts_from_img_alt(input_image,aAPR.particles_intensities);
//    sample_parts_from_img_downsampled(apr,downsampled_img);
//
//    std::swap(input_image, downsampled_img.back());
//}
//
///**
//* Samples particles from an image using an image tree (img_by_level is a vector of images)
//*/
//template<typename DataType>
//template<typename U>
//void GenData<DataType>::sample_parts_from_img_downsampled(APR& apr,std::vector<PixelData<U>>& img_by_level){
//    auto it = apr.iterator();
//    this->init(apr);
//
//    for (unsigned int level = it.level_min(); level <= it.level_max(); ++level) {
//#ifdef HAVE_OPENMP
//#pragma omp parallel for schedule(dynamic) firstprivate(it)
//#endif
//        for (int z = 0; z < it.z_num(level); ++z) {
//            for (int x = 0; x < it.x_num(level); ++x) {
//                for (it.begin(level, z, x);it <it.end();it++) {
//
//                    (*this)[it] = (DataType) img_by_level[level].at(it.y(),x,z);
//                }
//            }
//        }
//    }
//}



#endif //LIBAPR_GENDATA_HPP
