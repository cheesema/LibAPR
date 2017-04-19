#include <algorithm>
#include <iostream>

#include "ray_cast.h"
#include "../../src/data_structures/meshclass.h"
#include "../../src/io/readimage.h"

#include "../../src/algorithm/gradient.hpp"
#include "../../src/data_structures/particle_map.hpp"
#include "../../src/data_structures/Tree/PartCellStructure.hpp"
#include "../../src/algorithm/level.hpp"
#include "../../src/io/writeimage.h"
#include "../../src/io/write_parts.h"
#include "../../src/io/partcell_io.h"
#include "../../src/data_structures/Tree/PartCellParent.hpp"
#include "../../src/numerics/ray_cast.hpp"
#include "../../src/numerics/filter_numerics.hpp"
#include "../../src/numerics/misc_numerics.hpp"

#include "../../src/data_structures/APR/APR.hpp"

bool command_option_exists(char **begin, char **end, const std::string &option)
{
    return std::find(begin, end, option) != end;
}

char* get_command_option(char **begin, char **end, const std::string &option)
{
    char ** itr = std::find(begin, end, option);
    if (itr != end && ++itr != end)
    {
        return *itr;
    }
    return 0;
}

cmdLineOptions read_command_line_options(int argc, char **argv, Part_rep& part_rep){

    cmdLineOptions result;

    if(argc == 1) {
        std::cerr << "Usage: \"pipeline -i inputfile [-t] [-s statsfile -d directory] [-o outputfile]\"" << std::endl;
        exit(1);
    }

    if(command_option_exists(argv, argv + argc, "-i"))
    {
        result.input = std::string(get_command_option(argv, argv + argc, "-i"));
    } else {
        std::cout << "Input file required" << std::endl;
        exit(2);
    }

    if(command_option_exists(argv, argv + argc, "-o"))
    {
        result.output = std::string(get_command_option(argv, argv + argc, "-o"));
    }



    if(command_option_exists(argv, argv + argc, "-d"))
    {
        result.directory = std::string(get_command_option(argv, argv + argc, "-d"));
    }
    if(command_option_exists(argv, argv + argc, "-s"))
    {
        result.stats = std::string(get_command_option(argv, argv + argc, "-s"));
        get_image_stats(part_rep.pars, result.directory, result.stats);
        result.stats_file = true;
    }
    if(command_option_exists(argv, argv + argc, "-t"))
    {
        part_rep.timer.verbose_flag = true;
    }

    if(command_option_exists(argv, argv + argc, "-org_file"))
    {
        result.org_file = std::string(get_command_option(argv, argv + argc, "-org_file"));
    }

    return result;

}


int main(int argc, char **argv) {
    
    Part_rep part_rep;
    
    // INPUT PARSING
    
    cmdLineOptions options = read_command_line_options(argc, argv, part_rep);
    
    // COMPUTATIONS
    PartCellStructure<float,uint64_t> pc_struct;
    
    //output
    std::string file_name = options.directory + options.input;
    
    read_apr_pc_struct(pc_struct,file_name);

    

    Part_timer timer;

    /////////////////
    //
    //  Parameters
    ////////////////

    proj_par proj_pars;

    proj_pars.theta_0 = -3.14;
    proj_pars.theta_final = 3.14;
    proj_pars.radius_factor = .98f;
    proj_pars.theta_delta = .025f;
    proj_pars.scale_z = 4.0f;



    APR<float> curr_apr(pc_struct);


    apr_perspective_raycast(curr_apr.y_vec,curr_apr.particles_int,proj_pars,[] (const uint16_t& a,const uint16_t& b) {return std::max(a,b);});



    if(options.org_file != ""){

        Mesh_data<uint16_t> input_image;

        load_image_tiff(input_image, options.org_file);

        perpsective_mesh_raycast(pc_struct,proj_pars,input_image);

    }

    ///////////////////////////////////
    //
    //  Normalized Gradient Ray Cast
    //
    //////////////////////////////////
    std::vector<float> delta = {1,1,1};


//    ExtraPartCellData<float> normalized_grad =  compute_normalized_grad_mag<float,float,uint64_t>(pc_struct,3,delta);
//
//    shift_particles_from_cells(curr_apr.part_new,normalized_grad);
//
//    ExtraPartCellData<std::array<float,3>> grad_norm = adaptive_gradient_normal(pc_struct,delta);
//
//    //threshold by intensity first
//    float intensity_threshold = 3;
//
//    threshold_parts(normalized_grad,curr_apr.particles_int,intensity_threshold,0,std::less<float>());
//
//    float min_th = .2;
//    float set_val = 0;
//
//    threshold_parts(normalized_grad,min_th,set_val,std::less<float>());
//
//    apr_perspective_raycast_depth(curr_apr.y_vec,normalized_grad,curr_apr.part_new.particle_data,proj_pars,[] (const uint16_t& a,const uint16_t& b) {return std::max(a,b);},true);


//
//    adapt_grad = transform_parts(adapt_grad,[] (const float& a) {return 1000*a;});
//
//    shift_particles_from_cells(part_new,adapt_grad);
//
//
//
//    apr_prospective_raycast(y_vec,adapt_grad,proj_pars,[] (const uint16_t& a,const uint16_t& b) {return std::max(a,b);});


}


