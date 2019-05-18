//
// Created by cheesema on 16/03/17.
//

#ifndef PARTPLAY_APR_HPP
#define PARTPLAY_APR_HPP

#include "APRAccess.hpp"
#include "APRIterator.hpp"

//template<typename ImageType>
class APR {

//    APRWriter apr_writer;
//    APRReconstruction apr_recon;

public:
    APRParameters parameters;
    APRAccess apr_access;
    //APRConverter<ImageType> apr_converter;
//    APRCompress<ImageType> apr_compress;
//    APRTree<ImageType> apr_tree;
//
//    ExtraParticleData<ImageType> particles_intensities;

    std::string name;
    //APRParameters parameters;

    uint64_t level_max() const { return apr_access.l_max; }
    uint64_t level_min() const { return apr_access.l_min; }
    inline uint64_t spatial_index_x_max(const unsigned int level) const { return apr_access.x_num[level]; }
    inline uint64_t spatial_index_y_max(const unsigned int level) const { return apr_access.y_num[level]; }
    inline uint64_t spatial_index_z_max(const unsigned int level) const { return apr_access.z_num[level]; }
    inline uint64_t total_number_particles() const { return apr_access.total_number_particles; }
    unsigned int orginal_dimensions(int dim) const { return apr_access.org_dims[dim]; }

    APRIterator iterator() {
        return APRIterator(apr_access);
    }

//    APR(){
//        //default
//    }

    //APR(APR<ImageType>& copyAPR){
      //  copy_from_APR(copyAPR);
    //}

    void copy_from_APR(APR& copyAPR){
        apr_access = copyAPR.apr_access;
        //particles_intensities = copyAPR.particles_intensities;
        //apr_tree = copyAPR.apr_tree;
        //parameters = copyAPR.parameters;
        name = copyAPR.name;
    }

    ///////////////////////////////////
    /// APR Generation Methods (Calls members of the APRConverter class)
    //////////////////////////////////

//    bool get_apr(){
//        //copy across parameters
//        APRConverter<ImageType> aprConverter;
//        aprConverter.par = parameters;
//        return aprConverter.get_apr(*this);
//    }
//
//    template<typename T>
//    bool get_apr(PixelData<T>& input_img){
//        APRConverter<ImageType> aprConverter;
//        aprConverter.par = parameters;
//        return aprConverter.get_apr_method(*this, input_img);
//    }

    ///////////////////////////////////
    /// APR IO Methods (Calls members of the APRWriter class)
    //////////////////////////////////

//    void read_apr(std::string file_name){
//        apr_writer.read_apr(*this,file_name);
//    }
//
//    void read_apr(std::string file_name,bool read_tree,unsigned int max_level_delta){
//        apr_writer.read_apr(*this,file_name,read_tree,max_level_delta);
//    }
//
//    FileSizeInfo write_apr(std::string save_loc,std::string file_name){
//        return apr_writer.write_apr(*this, save_loc,file_name);
//    }
//
//    FileSizeInfo write_apr(std::string save_loc,std::string file_name,APRCompress<ImageType>& apr_compressor,unsigned int blosc_comp_type,unsigned int blosc_comp_level,unsigned int blosc_shuffle,bool write_tree = false){
//        return apr_writer.write_apr((*this),save_loc, file_name, apr_compressor,blosc_comp_type ,blosc_comp_level,blosc_shuffle,write_tree);
//    }
//
//    FileSizeInfo write_apr(std::string save_loc,std::string file_name,unsigned int blosc_comp_type,unsigned int blosc_comp_level,unsigned int blosc_shuffle,bool write_tree = false){
//
//        return apr_writer.write_apr((*this),save_loc, file_name, apr_compress,blosc_comp_type ,blosc_comp_level,blosc_shuffle,write_tree);
//    }
//
//    //generate APR that can be read by paraview
//    template<typename T>
//    void write_apr_paraview(std::string save_loc,std::string file_name,ExtraParticleData<T>& parts){
//        apr_writer.write_apr_paraview((*this), save_loc,file_name,parts);
//    }
//
//    //write out ExtraPartCellData
//    template< typename S>
//    void write_particles_only( std::string save_loc,std::string file_name,ExtraParticleData<S>& parts_extra){
//        apr_writer.write_particles_only(save_loc, file_name, parts_extra);
//    }
//
//    //read in ExtraPartCellData
//    template<typename T>
//    void read_parts_only(std::string file_name,ExtraParticleData<T>& extra_parts){
//        apr_writer.read_parts_only(file_name,extra_parts);
//    }

    ////////////////////////
    ///  APR Reconstruction Methods (Calls APRReconstruction methods)
    //////////////////////////

    /**
     * Takes in a APR and creates piece-wise constant image
     */
//    template<typename U,typename V>
//    void interp_img(PixelData<U>& img,ExtraParticleData<V>& parts){
//        apr_recon.interp_img((*this),img, parts);
//    }
//
//    /**
//     * Returns an image of the depth, this is down-sampled by one, as the Particle Cell solution reflects this
//     */
//    template<typename U>
//    void interp_level_ds(PixelData<U>& img){
//        apr_recon.interp_depth_ds((*this),img);
//    }
//
//    /**
//     * Returns an image of the depth, this is down-sampled by one, as the Particle Cell solution reflects this
//     */
//    template<typename U>
//    void interp_level(PixelData<U>& img){
//        apr_recon.interp_level((*this), img);
//    }
//
//    /**
//     * Performs a smooth interpolation, based on the depth (level l) in each direction.
//     */
//    template<typename U,typename V>
//    void interp_parts_smooth(PixelData<U>& out_image,ExtraParticleData<V>& interp_data,std::vector<float> scale_d = {2,2,2}){
//        apr_recon.interp_parts_smooth((*this),out_image,interp_data,scale_d);
//    }


};


#endif //PARTPLAY_APR_HPP
