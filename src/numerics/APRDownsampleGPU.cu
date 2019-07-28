//
// Created by cheesema on 05.04.18.
//

#include "APRDownsampleGPU.hpp"

//__device__ void get_row_begin_end(std::size_t* index_begin,
//                                  std::size_t* index_end,
//                                  std::size_t xz_start,
//                                  const uint64_t* xz_end_vec){
//
//    *index_end = (xz_end_vec[xz_start]);
//
//    if (xz_start == 0) {
//        *index_begin = 0;
//    } else {
//        *index_begin =(xz_end_vec[xz_start-1]);
//    }
//}

template<typename inputType, typename outputType>
__global__ void down_sample_avg_new(const uint64_t* level_xz_vec,
                                const uint64_t* xz_end_vec,
                                const uint16_t* y_vec,
                                const inputType* input_particles,
                                const uint64_t* level_xz_vec_tree,
                                const uint64_t* xz_end_vec_tree,
                                const uint16_t* y_vec_tree,
                                outputType* particle_data_output,
                                const int z_num,
                                const int x_num,
                                const int y_num,
                                const int z_num_parent,
                                const int x_num_parent,
                                const int y_num_parent,
                                const int level,const int* offset_ind) {



    const int index = offset_ind[blockIdx.x];

    const int z_p = index/x_num_parent;
    const int x_p = index - z_p*x_num_parent;

//
//    const int x_index = (2 * blockIdx.x + threadIdx.x/64);
//    const int z_index = (2 * blockIdx.z + ((threadIdx.x)/32)%2);


    const int x_index = (2 * x_p + threadIdx.x/64);
    const int z_index = (2 * z_p + ((threadIdx.x)/32)%2);

    const int block = threadIdx.x/32;
    const int local_th = (threadIdx.x%32);

    __shared__ size_t global_index_begin_0_s[4];
    __shared__ size_t global_index_end_0_s[4];

    size_t global_index_begin_p;
    size_t global_index_end_p;

    //remove these with registers
    //__shared__ float f_cache[5][32];
    //__shared__ int y_cache[5][32];


    int current_y = -1;
    int current_y_p = -1;

    if( (x_index >= x_num) || (z_index >= z_num) ){

        return; //out of bounds
    } else {

        if(threadIdx.x==0){

        }
        //get_row_begin_end(&global_index_begin_0, &global_index_end_0, x_index + z_index*x_num + level_xz_vec[level], xz_end_vec);
        if((local_th==0) ) {
            size_t xz_start_s = x_index + z_index * x_num + level_xz_vec[level];
            global_index_begin_0_s[block] = xz_end_vec[xz_start_s - 1];
            global_index_end_0_s[block] = xz_end_vec[xz_start_s];
        }
    }
    __syncthreads();

    if(global_index_begin_0_s[0] == global_index_end_0_s[0]){
        //printf("%d \n",x_p);
        //printf("%d \n",z_p);
        //return;
    }


    size_t global_index_begin_0 = global_index_begin_0_s[block];
    size_t global_index_end_0 = global_index_end_0_s[block];
//    size_t xz_start_s = x_index + z_index * x_num + level_xz_vec[level];
//    size_t global_index_begin_0 = xz_end_vec[xz_start_s - 1];
//    size_t global_index_end_0 = xz_end_vec[xz_start_s];



    //keep these
    __shared__ float parent_cache[8][16];

    float current_val = 0;

    parent_cache[2*block][local_th/2] = 0;
    parent_cache[2*block+1][local_th/2] = 0;

    float scale_factor_xz = (((2*x_num_parent != x_num) && x_p==(x_num_parent-1) ) + ((2*z_num_parent != z_num) && z_p==(z_num_parent-1) ))*2;

    if(scale_factor_xz == 0){
        scale_factor_xz = 1;
    }

    float scale_factor_yxz = scale_factor_xz;

    if((2*y_num_parent != y_num)){
        scale_factor_yxz = scale_factor_xz*2;
    }


    //get_row_begin_end(&global_index_begin_p, &global_index_end_p, blockIdx.x + blockIdx.z*x_num_parent + level_xz_vec_tree[level-1], xz_end_vec_tree);
    size_t xz_start = x_p + z_p*x_num_parent + level_xz_vec_tree[level-1];
    global_index_begin_p = xz_end_vec_tree[xz_start - 1];
    global_index_end_p = xz_end_vec_tree[xz_start];

    //initialize (i=0)
    if ((global_index_begin_0 + local_th) < global_index_end_0) {
        current_val = input_particles[global_index_begin_0 + local_th];
        current_y =  y_vec[global_index_begin_0 + local_th];
    }


    if (block == 3) {

        if (( global_index_begin_p + local_th) < global_index_end_p) {

            current_y_p = y_vec_tree[global_index_begin_p + local_th];

        }

    }

    uint16_t start = y_vec[global_index_begin_0];
    uint16_t end = y_vec[global_index_end_0];

    uint16_t sparse_block = 0;
    int sparse_block_p = 0;

    const uint16_t number_y_chunk = min(end/32+2,(y_num+31)/32);
    //const uint16_t number_y_chunk = (y_num+31)/32;

    //start/32
    for (int y_block = start/32; y_block < number_y_chunk; ++y_block) {

        __syncthreads();
        //value less then current chunk then update.
        if (current_y < y_block * 32) {
            sparse_block++;
            if ((sparse_block * 32 + global_index_begin_0 + local_th) < global_index_end_0) {
                current_val = input_particles[sparse_block * 32 + global_index_begin_0 + local_th];

                current_y = y_vec[sparse_block * 32 + global_index_begin_0 + local_th];
            }
        }

        //current_y = y_cache[block][local_th];
        __syncthreads();

        //update the down-sampling caches
        if ((current_y < (y_block + 1) * 32) && (current_y >= (y_block) * 32)) {

            parent_cache[2*block+current_y%2][(current_y/2) % 16] = (1.0f/8.0f)*current_val;
        }

        __syncthreads();
        //fetch the parent particle data
        if (block == 3) {
            if (current_y_p < ((y_block * 32)/2)) {
                sparse_block_p++;


                if ((sparse_block_p * 32 + global_index_begin_p + local_th) < global_index_end_p) {

                    current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p + local_th];

                }

            }


        }
        __syncthreads();

        if(block ==3) {
            //output

            if (current_y_p < ((y_block+1) * 32)/2) {
                if ((sparse_block_p * 32 + global_index_begin_p + local_th) < global_index_end_p) {

                    if(current_y_p == (y_num_parent-1)) {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p + local_th] =
                                scale_factor_yxz*( parent_cache[0][current_y_p % 16] +
                                                   parent_cache[1][current_y_p % 16] +
                                                   parent_cache[2][current_y_p % 16] +
                                                   parent_cache[3][current_y_p % 16] +
                                                   parent_cache[4][current_y_p % 16] +
                                                   parent_cache[5][current_y_p % 16] +
                                                   parent_cache[6][current_y_p % 16] +
                                                   parent_cache[7][current_y_p % 16]);



                    } else {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p + local_th] =
                                scale_factor_xz*( parent_cache[0][current_y_p % 16] +
                                                  parent_cache[1][current_y_p % 16] +
                                                  parent_cache[2][current_y_p % 16] +
                                                  parent_cache[3][current_y_p % 16] +
                                                  parent_cache[4][current_y_p % 16] +
                                                  parent_cache[5][current_y_p % 16] +
                                                  parent_cache[6][current_y_p % 16] +
                                                  parent_cache[7][current_y_p % 16]);


                    }
                }
            }

        }
        __syncthreads();
        parent_cache[2*block][local_th/2] = 0;
        parent_cache[2*block+1][local_th/2] = 0;
    }
}




template<typename inputType, typename outputType>
__global__ void down_sample_avg(const uint64_t* level_xz_vec,
                                const uint64_t* xz_end_vec,
                                const uint16_t* y_vec,
                                const inputType* input_particles,
                                const uint64_t* level_xz_vec_tree,
                                const uint64_t* xz_end_vec_tree,
                                const uint16_t* y_vec_tree,
                                outputType* particle_data_output,
                                const int z_num,
                                const int x_num,
                                const int y_num,
                                const int z_num_parent,
                                const int x_num_parent,
                                const int y_num_parent,
                                const int level) {

    const int x_index = (2 * blockIdx.x + threadIdx.x/64);
    const int z_index = (2 * blockIdx.z + ((threadIdx.x)/32)%2);

    const int block = threadIdx.x/32;
    const int local_th = (threadIdx.x%32);

    __shared__ size_t global_index_begin_0_s[4];
    __shared__ size_t global_index_end_0_s[4];

    size_t global_index_begin_p;
    size_t global_index_end_p;

    //remove these with registers
    //__shared__ float f_cache[5][32];
    //__shared__ int y_cache[5][32];


    int current_y = -1;
    int current_y_p = -1;

    if( (x_index >= x_num) || (z_index >= z_num) ){

         return; //out of bounds
    } else {

        if(threadIdx.x==0){

        }
        //get_row_begin_end(&global_index_begin_0, &global_index_end_0, x_index + z_index*x_num + level_xz_vec[level], xz_end_vec);
        if((local_th==0) ) {
            size_t xz_start_s = x_index + z_index * x_num + level_xz_vec[level];
            global_index_begin_0_s[block] = xz_end_vec[xz_start_s - 1];
            global_index_end_0_s[block] = xz_end_vec[xz_start_s];
        }
    }
    __syncthreads();

    if(global_index_begin_0_s[0] == global_index_end_0_s[0]){
        return;
    }

    size_t global_index_begin_0 = global_index_begin_0_s[block];
    size_t global_index_end_0 = global_index_end_0_s[block];




    //keep these
    __shared__ float parent_cache[8][16];

    float current_val = 0;

    parent_cache[2*block][local_th/2] = 0;
    parent_cache[2*block+1][local_th/2] = 0;

    float scale_factor_xz = (((2*x_num_parent != x_num) && blockIdx.x==(x_num_parent-1) ) + ((2*z_num_parent != z_num) && blockIdx.z==(z_num_parent-1) ))*2;

    if(scale_factor_xz == 0){
        scale_factor_xz = 1;
    }

    float scale_factor_yxz = scale_factor_xz;

    if((2*y_num_parent != y_num)){
        scale_factor_yxz = scale_factor_xz*2;
    }


    //get_row_begin_end(&global_index_begin_p, &global_index_end_p, blockIdx.x + blockIdx.z*x_num_parent + level_xz_vec_tree[level-1], xz_end_vec_tree);
    size_t xz_start = blockIdx.x + blockIdx.z*x_num_parent + level_xz_vec_tree[level-1];
    global_index_begin_p = xz_end_vec_tree[xz_start - 1];
    global_index_end_p = xz_end_vec_tree[xz_start];

    //initialize (i=0)
    if ((global_index_begin_0 + local_th) < global_index_end_0) {
        current_val = input_particles[global_index_begin_0 + local_th];
        current_y =  y_vec[global_index_begin_0 + local_th];
    }


    if (block == 3) {

        if (( global_index_begin_p + local_th) < global_index_end_p) {

            current_y_p = y_vec_tree[global_index_begin_p + local_th];

        }

    }

    uint16_t sparse_block = 0;
    int sparse_block_p = 0;
    const uint16_t number_y_chunk = (y_num+31)/32;

    for (int y_block = 0; y_block < number_y_chunk; ++y_block) {

        __syncthreads();
        //value less then current chunk then update.
        if (current_y < y_block * 32) {
            sparse_block++;
            if ((sparse_block * 32 + global_index_begin_0 + local_th) < global_index_end_0) {
                current_val = input_particles[sparse_block * 32 + global_index_begin_0 + local_th];

                current_y = y_vec[sparse_block * 32 + global_index_begin_0 + local_th];
            }
        }

        //current_y = y_cache[block][local_th];
        __syncthreads();

        //update the down-sampling caches
        if ((current_y < (y_block + 1) * 32) && (current_y >= (y_block) * 32)) {

            parent_cache[2*block+current_y%2][(current_y/2) % 16] = (1.0f/8.0f)*current_val;
            //parent_cache[2*block+current_y%2][(current_y/2) % 16] = 1;

        }

        __syncthreads();
        //fetch the parent particle data
        if (block == 3) {
            if (current_y_p < ((y_block * 32)/2)) {
                sparse_block_p++;


                if ((sparse_block_p * 32 + global_index_begin_p + local_th) < global_index_end_p) {

                    current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p + local_th];

                }

            }


        }
        __syncthreads();

        if(block ==3) {
            //output

            if (current_y_p < ((y_block+1) * 32)/2) {
                if ((sparse_block_p * 32 + global_index_begin_p + local_th) < global_index_end_p) {

                    if(current_y_p == (y_num_parent-1)) {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p + local_th] =
                                scale_factor_yxz*( parent_cache[0][current_y_p % 16] +
                                                   parent_cache[1][current_y_p % 16] +
                                                   parent_cache[2][current_y_p % 16] +
                                                   parent_cache[3][current_y_p % 16] +
                                                   parent_cache[4][current_y_p % 16] +
                                                   parent_cache[5][current_y_p % 16] +
                                                   parent_cache[6][current_y_p % 16] +
                                                   parent_cache[7][current_y_p % 16]);



                    } else {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p + local_th] =
                                scale_factor_xz*( parent_cache[0][current_y_p % 16] +
                                                  parent_cache[1][current_y_p % 16] +
                                                  parent_cache[2][current_y_p % 16] +
                                                  parent_cache[3][current_y_p % 16] +
                                                  parent_cache[4][current_y_p % 16] +
                                                  parent_cache[5][current_y_p % 16] +
                                                  parent_cache[6][current_y_p % 16] +
                                                  parent_cache[7][current_y_p % 16]);


                    }
                }
            }

        }
        __syncthreads();
        parent_cache[2*block][local_th/2] = 0;
        parent_cache[2*block+1][local_th/2] = 0;
    }
}

template<typename inputType, typename outputType>
__global__ void down_sample_avg_interior(const uint64_t* level_xz_vec,
                                         const uint64_t* xz_end_vec,
                                         const uint16_t* y_vec,
                                         const inputType* input_particles,
                                         const uint64_t* level_xz_vec_tree,
                                         const uint64_t* xz_end_vec_tree,
                                         const uint16_t* y_vec_tree,
                                         outputType* particle_data_output,
                                         const int z_num,
                                         const int x_num,
                                         const int y_num,
                                         const int z_num_parent,
                                         const int x_num_parent,
                                         const int y_num_parent,
                                         const int level) {
    //
    //  This step is required for the interior down-sampling
    //

    //Local identifiers.
    int x_index = (2 * blockIdx.x + threadIdx.x/64);
    int z_index = (2 * blockIdx.z + ((threadIdx.x)/32)%2);

    const int block = threadIdx.x/32;

    const int local_th = (threadIdx.x%32);


    //Particles
    __shared__ std::size_t global_index_begin_0[4];
    __shared__ std::size_t global_index_end_0[4];

    //Parent Tree Particle Cells
    __shared__ std::size_t global_index_begin_p[4];
    __shared__ std::size_t global_index_end_p[4];

    //Interior Tree Particle Cells
    __shared__ std::size_t global_index_begin_t[4];
    __shared__ std::size_t global_index_end_t[4];


    int current_y=-1;
    int current_y_p=-1;
    int current_y_t=-1;
    float current_val=0;
    float current_val_t = 0;

    if((x_index >= x_num) || (z_index >= z_num) ){
        global_index_begin_t[block] = 1;
        global_index_end_t[block] = 0;

        global_index_begin_0[block] = 1;
        global_index_end_0[block] = 0;
         //return; //out of bounds
    } else {
        //get_row_begin_end(&global_index_begin_t, &global_index_end_t, x_index + z_index*x_num + level_xz_vec_tree[level], xz_end_vec_tree);
        //get_row_begin_end(&global_index_begin_0, &global_index_end_0, x_index + z_index*x_num + level_xz_vec[level], xz_end_vec);

        if(local_th == 0) {
            size_t xz_start = x_index + z_index * x_num + level_xz_vec_tree[level];
            global_index_begin_t[block] = xz_end_vec_tree[xz_start - 1];
            global_index_end_t[block] = xz_end_vec_tree[xz_start];

            xz_start = x_index + z_index * x_num + level_xz_vec[level];
            global_index_begin_0[block] = xz_end_vec[xz_start - 1];
            global_index_end_0[block] = xz_end_vec[xz_start];
        }

    }

    __syncthreads();

    //get_row_begin_end(&global_index_begin_p, &global_index_end_p, blockIdx.x + blockIdx.z*x_num_parent + level_xz_vec_tree[level-1], xz_end_vec_tree);

    if(local_th == 0) {
        size_t xz_start = blockIdx.x + blockIdx.z * x_num_parent + level_xz_vec_tree[level - 1];
        global_index_begin_p[block] = xz_end_vec_tree[xz_start - 1];
        global_index_end_p[block] = xz_end_vec_tree[xz_start];
    }

    __syncthreads();
    //initialize (i=0)
    if ((global_index_begin_0[block] + local_th) < global_index_end_0[block]) {

        current_y = y_vec[global_index_begin_0[block] + local_th];
        current_val = input_particles[global_index_begin_0[block] + local_th];

    }

    //tree interior
    if ((global_index_begin_t[block] + local_th) < global_index_end_t[block]) {

        current_y_t = y_vec_tree[global_index_begin_t[block] + local_th];
        current_val_t = particle_data_output[global_index_begin_t[block] + local_th];
    }

    if((global_index_begin_0[block] == global_index_end_0[block]) && (global_index_begin_t[block] == global_index_end_t[block])){
        return;
    }


    //shared memory caches

    __shared__ float parent_cache[8][16];


    parent_cache[2*block][local_th/2]=0;
    parent_cache[2*block+1][local_th/2]=0;

    float scale_factor_xz = (((2*x_num_parent != x_num) && blockIdx.x==(x_num_parent-1) ) + ((2*z_num_parent != z_num) && blockIdx.z==(z_num_parent-1) ))*2;

    if(scale_factor_xz == 0){
        scale_factor_xz = 1;
    }

    float scale_factor_yxz = scale_factor_xz;

    if((2*y_num_parent != y_num)){
        scale_factor_yxz = scale_factor_xz*2;
    }



    if (block == 3) {

        if (( global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

            current_y_p = y_vec_tree[global_index_begin_p[block] + local_th];

        }
    }

    int sparse_block = 0;
    int sparse_block_p = 0;
    int sparse_block_t = 0;

    __shared__ int start[4];
    __shared__ int end[4];
    __shared__ int number_y_chunk[4];

    if(local_th == 0) {
        start[block] = min(y_vec[global_index_begin_0[block]], y_vec_tree[global_index_begin_t[block]]);
        end[block] = max(y_vec[global_index_end_0[block]], y_vec_tree[global_index_end_t[block]]);
        number_y_chunk[block] = min(end[block] / 32 + 2, (y_num + 31) / 32);
    }

    __syncthreads();
    //const uint16_t number_y_chunk = (y_num+31)/32;

    for (int y_block = start[block]/32; y_block < (number_y_chunk[block]); ++y_block) {

        __syncthreads();
        //value less then current chunk then update.
        if (current_y < (y_block * 32)) {
            sparse_block++;
            if ((sparse_block * 32 + global_index_begin_0[block] + local_th) < global_index_end_0[block]) {

                current_val = input_particles[sparse_block * 32 + global_index_begin_0[block] + local_th];
                current_y = y_vec[sparse_block * 32 + global_index_begin_0[block] + local_th];
            }
        }

        //interior tree update
        if (current_y_t < (y_block * 32)) {
            sparse_block_t++;
            if ((sparse_block_t * 32 + global_index_begin_t[block] + local_th) < global_index_end_t[block]) {

                current_val_t = particle_data_output[sparse_block_t * 32 + global_index_begin_t[block] + local_th];
                current_y_t = y_vec_tree[sparse_block_t * 32 + global_index_begin_t[block] + local_th];
            }
        }
        // current_y_t = y_cache_t[block][local_th];

        __syncthreads();
        //update the down-sampling caches
        if ((current_y < (y_block + 1) * 32) && (current_y >= (y_block) * 32)) {

            parent_cache[2*block+current_y%2][(current_y/2) % 16] = (1.0/8.0f)*current_val;
            //parent_cache[2*block+current_y%2][(current_y/2) % 16] = 1;

        }
        __syncthreads();



        //now the interior tree nodes
        if ((current_y_t < (y_block + 1) * 32) && (current_y_t >= (y_block) * 32)) {

            parent_cache[2*block + current_y_t%2][(current_y_t/2) % 16] = (1.0/8.0f)*current_val_t;
            //parent_cache[2*block+current_y_t%2][(current_y_t/2) % 16] = 1;
            //parent_cache[0][(current_y_t/2) % 16] = current_y_t/2;
        }
        __syncthreads();


        if (block == 3) {

            if (current_y_p < ((y_block * 32)/2)) {
                sparse_block_p++;

                if ((sparse_block_p * 32 + global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

                    //y_cache[4][local_th] = particle_y_child[sparse_block_p * 32 + global_index_begin_p + local_th];
                    current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p[block] + local_th];

                }
            }
        }

        __syncthreads();

        //local_sum
        if(block ==3) {
            //output
            //current_y_p = y_cache[4][local_th];
            current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p[block] + local_th];

            if (current_y_p < ((y_block+1) * 32)/2 && current_y_p >= ((y_block) * 32)/2) {
                if ((sparse_block_p * 32 + global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

                    if (current_y_p == (y_num_parent - 1)) {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p[block] + local_th] =
                                scale_factor_yxz * (parent_cache[0][current_y_p % 16] +
                                                    parent_cache[1][current_y_p % 16] +
                                                    parent_cache[2][current_y_p % 16] +
                                                    parent_cache[3][current_y_p % 16] +
                                                    parent_cache[4][current_y_p % 16] +
                                                    parent_cache[5][current_y_p % 16] +
                                                    parent_cache[6][current_y_p % 16] +
                                                    parent_cache[7][current_y_p % 16]);


                    } else {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p[block] + local_th] =
                                scale_factor_xz * ( parent_cache[0][current_y_p % 16] +
                                                    parent_cache[1][current_y_p % 16] +
                                                    parent_cache[2][current_y_p % 16] +
                                                    parent_cache[3][current_y_p % 16] +
                                                    parent_cache[4][current_y_p % 16] +
                                                    parent_cache[5][current_y_p % 16] +
                                                    parent_cache[6][current_y_p % 16] +
                                                    parent_cache[7][current_y_p % 16]);

                    }
                }
            }
        }

        __syncthreads();

        parent_cache[2*block][local_th/2] = 0;
        parent_cache[2*block+1][local_th/2] = 0;

    }
}

template<typename inputType, typename outputType>
__global__ void down_sample_avg_interior_new(const uint64_t* level_xz_vec,
                                         const uint64_t* xz_end_vec,
                                         const uint16_t* y_vec,
                                         const inputType* input_particles,
                                         const uint64_t* level_xz_vec_tree,
                                         const uint64_t* xz_end_vec_tree,
                                         const uint16_t* y_vec_tree,
                                         outputType* particle_data_output,
                                         const int z_num,
                                         const int x_num,
                                         const int y_num,
                                         const int z_num_parent,
                                         const int x_num_parent,
                                         const int y_num_parent,
                                         const int level,const int* offset_ind) {
    //
    //  This step is required for the interior down-sampling
    //

    const int index = offset_ind[blockIdx.x];

    const int z_p = index/x_num_parent;
    const int x_p = index - z_p*x_num_parent;

    //Local identifiers.
    int x_index = (2 * x_p + threadIdx.x/64);
    int z_index = (2 * z_p + ((threadIdx.x)/32)%2);

    const int block = threadIdx.x/32;

    const int local_th = (threadIdx.x%32);


    //Particles
    __shared__ std::size_t global_index_begin_0[4];
    __shared__ std::size_t global_index_end_0[4];

    //Parent Tree Particle Cells
    __shared__ std::size_t global_index_begin_p[4];
    __shared__ std::size_t global_index_end_p[4];

    //Interior Tree Particle Cells
    __shared__ std::size_t global_index_begin_t[4];
    __shared__ std::size_t global_index_end_t[4];


    int current_y=-1;
    int current_y_p=-1;
    int current_y_t=-1;
    float current_val=0;
    float current_val_t = 0;

    if((x_index >= x_num) || (z_index >= z_num) ){
        global_index_begin_t[block] = 1;
        global_index_end_t[block] = 0;

        global_index_begin_0[block] = 1;
        global_index_end_0[block] = 0;
        //return; //out of bounds
    } else {
        //get_row_begin_end(&global_index_begin_t, &global_index_end_t, x_index + z_index*x_num + level_xz_vec_tree[level], xz_end_vec_tree);
        //get_row_begin_end(&global_index_begin_0, &global_index_end_0, x_index + z_index*x_num + level_xz_vec[level], xz_end_vec);

        if(local_th == 0) {
            size_t xz_start = x_index + z_index * x_num + level_xz_vec_tree[level];
            global_index_begin_t[block] = xz_end_vec_tree[xz_start - 1];
            global_index_end_t[block] = xz_end_vec_tree[xz_start];

            xz_start = x_index + z_index * x_num + level_xz_vec[level];
            global_index_begin_0[block] = xz_end_vec[xz_start - 1];
            global_index_end_0[block] = xz_end_vec[xz_start];
        }

    }

    __syncthreads();

    //get_row_begin_end(&global_index_begin_p, &global_index_end_p, blockIdx.x + blockIdx.z*x_num_parent + level_xz_vec_tree[level-1], xz_end_vec_tree);

    if(local_th == 0) {
        size_t xz_start = x_p + z_p * x_num_parent + level_xz_vec_tree[level - 1];
        global_index_begin_p[block] = xz_end_vec_tree[xz_start - 1];
        global_index_end_p[block] = xz_end_vec_tree[xz_start];
    }

    __syncthreads();
    //initialize (i=0)
    if ((global_index_begin_0[block] + local_th) < global_index_end_0[block]) {

        current_y = y_vec[global_index_begin_0[block] + local_th];
        current_val = input_particles[global_index_begin_0[block] + local_th];

    }

    //tree interior
    if ((global_index_begin_t[block] + local_th) < global_index_end_t[block]) {

        current_y_t = y_vec_tree[global_index_begin_t[block] + local_th];
        current_val_t = particle_data_output[global_index_begin_t[block] + local_th];
    }

    if((global_index_begin_0[block] == global_index_end_0[block]) && (global_index_begin_t[block] == global_index_end_t[block])){
        return;
    }


    //shared memory caches

    __shared__ float parent_cache[8][16];


    parent_cache[2*block][local_th/2]=0;
    parent_cache[2*block+1][local_th/2]=0;

    float scale_factor_xz = (((2*x_num_parent != x_num) && x_p==(x_num_parent-1) ) + ((2*z_num_parent != z_num) && z_p==(z_num_parent-1) ))*2;

    if(scale_factor_xz == 0){
        scale_factor_xz = 1;
    }

    float scale_factor_yxz = scale_factor_xz;

    if((2*y_num_parent != y_num)){
        scale_factor_yxz = scale_factor_xz*2;
    }



    if (block == 3) {

        if (( global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

            current_y_p = y_vec_tree[global_index_begin_p[block] + local_th];

        }
    }

    int sparse_block = 0;
    int sparse_block_p = 0;
    int sparse_block_t = 0;

    __shared__ int start[4];
    __shared__ int end[4];
    __shared__ int number_y_chunk[4];

    if(local_th == 0) {
        start[block] = min(y_vec[global_index_begin_0[block]], y_vec_tree[global_index_begin_t[block]]);
        end[block] = max(y_vec[global_index_end_0[block]], y_vec_tree[global_index_end_t[block]]);
        number_y_chunk[block] = min(end[block] / 32 + 2, (y_num + 31) / 32);
    }

    __syncthreads();
    //const uint16_t number_y_chunk = (y_num+31)/32;

    for (int y_block = start[block]/32; y_block < (number_y_chunk[block]); ++y_block) {

        __syncthreads();
        //value less then current chunk then update.
        if (current_y < (y_block * 32)) {
            sparse_block++;
            if ((sparse_block * 32 + global_index_begin_0[block] + local_th) < global_index_end_0[block]) {

                current_val = input_particles[sparse_block * 32 + global_index_begin_0[block] + local_th];
                current_y = y_vec[sparse_block * 32 + global_index_begin_0[block] + local_th];
            }
        }

        //interior tree update
        if (current_y_t < (y_block * 32)) {
            sparse_block_t++;
            if ((sparse_block_t * 32 + global_index_begin_t[block] + local_th) < global_index_end_t[block]) {

                current_val_t = particle_data_output[sparse_block_t * 32 + global_index_begin_t[block] + local_th];
                current_y_t = y_vec_tree[sparse_block_t * 32 + global_index_begin_t[block] + local_th];
            }
        }
        // current_y_t = y_cache_t[block][local_th];

        __syncthreads();
        //update the down-sampling caches
        if ((current_y < (y_block + 1) * 32) && (current_y >= (y_block) * 32)) {

            parent_cache[2*block+current_y%2][(current_y/2) % 16] = (1.0/8.0f)*current_val;
            //parent_cache[2*block+current_y%2][(current_y/2) % 16] = 1;

        }
        __syncthreads();



        //now the interior tree nodes
        if ((current_y_t < (y_block + 1) * 32) && (current_y_t >= (y_block) * 32)) {

            parent_cache[2*block + current_y_t%2][(current_y_t/2) % 16] = (1.0/8.0f)*current_val_t;
            //parent_cache[2*block+current_y_t%2][(current_y_t/2) % 16] = 1;
            //parent_cache[0][(current_y_t/2) % 16] = current_y_t/2;
        }
        __syncthreads();


        if (block == 3) {

            if (current_y_p < ((y_block * 32)/2)) {
                sparse_block_p++;

                if ((sparse_block_p * 32 + global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

                    //y_cache[4][local_th] = particle_y_child[sparse_block_p * 32 + global_index_begin_p + local_th];
                    current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p[block] + local_th];

                }
            }
        }

        __syncthreads();

        //local_sum
        if(block ==3) {
            //output
            //current_y_p = y_cache[4][local_th];
            current_y_p = y_vec_tree[sparse_block_p * 32 + global_index_begin_p[block] + local_th];

            if (current_y_p < ((y_block+1) * 32)/2 && current_y_p >= ((y_block) * 32)/2) {
                if ((sparse_block_p * 32 + global_index_begin_p[block] + local_th) < global_index_end_p[block]) {

                    if (current_y_p == (y_num_parent - 1)) {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p[block] + local_th] =
                                scale_factor_yxz * (parent_cache[0][current_y_p % 16] +
                                                    parent_cache[1][current_y_p % 16] +
                                                    parent_cache[2][current_y_p % 16] +
                                                    parent_cache[3][current_y_p % 16] +
                                                    parent_cache[4][current_y_p % 16] +
                                                    parent_cache[5][current_y_p % 16] +
                                                    parent_cache[6][current_y_p % 16] +
                                                    parent_cache[7][current_y_p % 16]);


                    } else {
                        particle_data_output[sparse_block_p * 32 + global_index_begin_p[block] + local_th] =
                                scale_factor_xz * ( parent_cache[0][current_y_p % 16] +
                                                    parent_cache[1][current_y_p % 16] +
                                                    parent_cache[2][current_y_p % 16] +
                                                    parent_cache[3][current_y_p % 16] +
                                                    parent_cache[4][current_y_p % 16] +
                                                    parent_cache[5][current_y_p % 16] +
                                                    parent_cache[6][current_y_p % 16] +
                                                    parent_cache[7][current_y_p % 16]);

                    }
                }
            }
        }

        __syncthreads();

        parent_cache[2*block][local_th/2] = 0;
        parent_cache[2*block+1][local_th/2] = 0;

    }
}

template<typename inputType, typename treeType>
void downsample_avg_init_wrapper(GPUAccessHelper& access, GPUAccessHelper& tree_access, std::vector<inputType>& input, std::vector<treeType>& tree_data) {

    tree_data.resize(tree_access.total_number_particles(),0);

    /// allocate GPU memory
    ScopedCudaMemHandler<inputType*, JUST_ALLOC> input_gpu(input.data(), input.size());
    ScopedCudaMemHandler<treeType*, JUST_ALLOC> tree_data_gpu(tree_data.data(), tree_data.size());

    std::vector<int> ne_counter;
    std::vector<int> ne_rows;

    ne_counter.resize(tree_access.level_max() + 3);

    int z = 0;
    int x = 0;

    for (int level = (tree_access.level_min() + 1); level <= (tree_access.level_max() + 1); ++level) {

        auto level_start = tree_access.linearAccess->level_xz_vec[level - 1];

        ne_counter[level] = ne_rows.size();

        for (z = 0; z < tree_access.z_num(level - 1); z++) {
            for (x = 0; x < tree_access.x_num(level - 1); ++x) {

                auto offset = x + z * tree_access.x_num(level - 1);
                auto xz_start = level_start + offset;

//intialize
                auto begin_index = tree_access.linearAccess->xz_end_vec[xz_start - 1];
                auto end_index = tree_access.linearAccess->xz_end_vec[xz_start];

                if (begin_index < end_index) {
                    ne_rows.push_back(x + z * tree_access.x_num(level - 1));
                }
            }
        }
    }
    ne_counter.back() = ne_rows.size();

    ScopedCudaMemHandler<int*, JUST_ALLOC> ne_rows_gpu(ne_rows.data(), ne_rows.size());
    ne_rows_gpu.copyH2D();

    tree_data_gpu.copyH2D();

    /// copy the input to the GPU
    input_gpu.copyH2D();

    for (int level = access.level_max(); level >= access.level_min(); --level) {

        if(level==access.level_max()) {
//
//            dim3 threads_l(128, 1, 1);
//
//            int x_blocks = (access.x_num(level) + 2 - 1) / 2;
//            int z_blocks = (access.z_num(level) + 2 - 1) / 2;
//
//            dim3 blocks_l(x_blocks, 1, z_blocks);
//
//            down_sample_avg << < blocks_l, threads_l >> >
//                                               (access.get_level_xz_vec_ptr(),
//                                                       access.get_xz_end_vec_ptr(),
//                                                       access.get_y_vec_ptr(),
//                                                       input_gpu.get(),
//                                                       tree_access.get_level_xz_vec_ptr(),
//                                                       tree_access.get_xz_end_vec_ptr(),
//                                                       tree_access.get_y_vec_ptr(),
//                                                       tree_data_gpu.get(),
//                                                       access.z_num(level),
//                                                       access.x_num(level),
//                                                       access.y_num(level),
//                                                       tree_access.z_num(level-1),
//                                                       tree_access.x_num(level-1),
//                                                       tree_access.y_num(level-1),
//                                                       level);




            dim3 threads_l(128, 1, 1);

            size_t ne_sz = ne_counter[level+1] - ne_counter[level];
            size_t offset = ne_counter[level];

            dim3 blocks_l(ne_sz, 1, 1);

            down_sample_avg_new << < blocks_l, threads_l >> >
                    (access.get_level_xz_vec_ptr(),
                                                       access.get_xz_end_vec_ptr(),
                                                       access.get_y_vec_ptr(),
                                                       input_gpu.get(),
                                                       tree_access.get_level_xz_vec_ptr(),
                                                       tree_access.get_xz_end_vec_ptr(),
                                                       tree_access.get_y_vec_ptr(),
                                                       tree_data_gpu.get(),
                                                       access.z_num(level),
                                                       access.x_num(level),
                                                       access.y_num(level),
                                                       tree_access.z_num(level-1),
                                                       tree_access.x_num(level-1),
                                                       tree_access.y_num(level-1),
                                                       level,ne_rows_gpu.get()+offset);


        } else {

            dim3 threads_l(128, 1, 1);

            size_t ne_sz = ne_counter[level+1] - ne_counter[level];
            size_t offset = ne_counter[level];

            dim3 blocks_l(ne_sz, 1, 1);

            down_sample_avg_interior_new << < blocks_l, threads_l >> >
                                                       (access.get_level_xz_vec_ptr(),
                                                        access.get_xz_end_vec_ptr(),
                                                        access.get_y_vec_ptr(),
                                                        input_gpu.get(),
                                                        tree_access.get_level_xz_vec_ptr(),
                                                        tree_access.get_xz_end_vec_ptr(),
                                                        tree_access.get_y_vec_ptr(),
                                                        tree_data_gpu.get(),
                                                        access.z_num(level),
                                                        access.x_num(level),
                                                        access.y_num(level),
                                                        tree_access.z_num(level-1),
                                                        tree_access.x_num(level-1),
                                                        tree_access.y_num(level-1),
                                                        level,ne_rows_gpu.get()+offset);
        }
        cudaDeviceSynchronize();
    }

    /// transfer the results back to the host
    tree_data_gpu.copyD2H();
}


template<typename inputType, typename treeType>
void downsample_avg_alt(GPUAccessHelper& access, GPUAccessHelper& tree_access, inputType* input_gpu, treeType* tree_data_gpu,int* ne_rows,std::vector<int>& ne_offset) {

    /// assumes input_gpu and tree_data_gpu are already on the device

    for (int level = access.level_max(); level >= access.level_min(); --level) {

        if(level == access.level_max()){

            dim3 threads_l(128, 1, 1);

            size_t ne_sz = ne_offset[level+1] - ne_offset[level];
            size_t offset = ne_offset[level];

            dim3 blocks_l(ne_sz, 1, 1);

            down_sample_avg_new << < blocks_l, threads_l >> >
                                           (access.get_level_xz_vec_ptr(),
                                                   access.get_xz_end_vec_ptr(),
                                                   access.get_y_vec_ptr(),
                                                   input_gpu,
                                                   tree_access.get_level_xz_vec_ptr(),
                                                   tree_access.get_xz_end_vec_ptr(),
                                                   tree_access.get_y_vec_ptr(),
                                                   tree_data_gpu,
                                                   access.z_num(level),
                                                   access.x_num(level),
                                                   access.y_num(level),
                                                   tree_access.z_num(level-1),
                                                   tree_access.x_num(level-1),
                                                   tree_access.y_num(level-1),
                                                   level,ne_rows + offset);


        } else {


            dim3 threads_l(128, 1, 1);

            size_t ne_sz = ne_offset[level+1] - ne_offset[level];
            size_t offset = ne_offset[level];

            dim3 blocks_l(ne_sz, 1, 1);


            down_sample_avg_interior_new << < blocks_l, threads_l >> >
                                                   (access.get_level_xz_vec_ptr(),
                                                           access.get_xz_end_vec_ptr(),
                                                           access.get_y_vec_ptr(),
                                                           input_gpu,
                                                           tree_access.get_level_xz_vec_ptr(),
                                                           tree_access.get_xz_end_vec_ptr(),
                                                           tree_access.get_y_vec_ptr(),
                                                           tree_data_gpu,
                                                           access.z_num(level),
                                                           access.x_num(level),
                                                           access.y_num(level),
                                                           tree_access.z_num(level-1),
                                                           tree_access.x_num(level-1),
                                                           tree_access.y_num(level-1),
                                                           level,ne_rows + offset);


//            dim3 threads_l(128, 1, 1);
//
//            int x_blocks = (access.x_num(level) + 2 - 1) / 2;
//            int z_blocks = (access.z_num(level) + 2 - 1) / 2;
//
//            dim3 blocks_l(x_blocks, 1, z_blocks);
//
//            down_sample_avg_interior<< < blocks_l, threads_l >> >
//                                                   (access.get_level_xz_vec_ptr(),
//                                                           access.get_xz_end_vec_ptr(),
//                                                           access.get_y_vec_ptr(),
//                                                           input_gpu,
//                                                           tree_access.get_level_xz_vec_ptr(),
//                                                           tree_access.get_xz_end_vec_ptr(),
//                                                           tree_access.get_y_vec_ptr(),
//                                                           tree_data_gpu,
//                                                           access.z_num(level),
//                                                           access.x_num(level),
//                                                           access.y_num(level),
//                                                           tree_access.z_num(level-1),
//                                                           tree_access.x_num(level-1),
//                                                           tree_access.y_num(level-1),
//                                                           level);
        }
        cudaDeviceSynchronize();
    }
}



template<typename inputType, typename treeType>
void downsample_avg_wrapper(GPUAccessHelper& access, GPUAccessHelper& tree_access, inputType* input_gpu, treeType* tree_data_gpu) {

    /// assumes input_gpu and tree_data_gpu are already on the device

    for (int level = access.level_max(); level >= access.level_min(); --level) {

        dim3 threads_l(128, 1, 1);

        int x_blocks = (access.x_num(level) + 2 - 1) / 2;
        int z_blocks = (access.z_num(level) + 2 - 1) / 2;

        dim3 blocks_l(x_blocks, 1, z_blocks);

        if(level==access.level_max()) {

            down_sample_avg << < blocks_l, threads_l >> >
                                           (access.get_level_xz_vec_ptr(),
                                                   access.get_xz_end_vec_ptr(),
                                                   access.get_y_vec_ptr(),
                                                   input_gpu,
                                                   tree_access.get_level_xz_vec_ptr(),
                                                   tree_access.get_xz_end_vec_ptr(),
                                                   tree_access.get_y_vec_ptr(),
                                                   tree_data_gpu,
                                                   access.z_num(level),
                                                   access.x_num(level),
                                                   access.y_num(level),
                                                   tree_access.z_num(level-1),
                                                   tree_access.x_num(level-1),
                                                   tree_access.y_num(level-1),
                                                   level);


        } else {

            down_sample_avg_interior<< < blocks_l, threads_l >> >
                                                   (access.get_level_xz_vec_ptr(),
                                                           access.get_xz_end_vec_ptr(),
                                                           access.get_y_vec_ptr(),
                                                           input_gpu,
                                                           tree_access.get_level_xz_vec_ptr(),
                                                           tree_access.get_xz_end_vec_ptr(),
                                                           tree_access.get_y_vec_ptr(),
                                                           tree_data_gpu,
                                                           access.z_num(level),
                                                           access.x_num(level),
                                                           access.y_num(level),
                                                           tree_access.z_num(level-1),
                                                           tree_access.x_num(level-1),
                                                           tree_access.y_num(level-1),
                                                           level);
        }
        cudaDeviceSynchronize();
    }
}