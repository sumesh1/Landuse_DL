#!/usr/bin/env python
# Filename: copyTolocal_postPro 
"""
introduction: copy prediction results from chpc cluster, then conduct post-processing


authors: Huang Lingcao
email:huanglingcao@gmail.com
add time: 11 October, 2019
"""

import os,sys
import time

HOME = os.path.expanduser('~')
codes_dir2 = HOME +'/codes/PycharmProjects/DeeplabforRS'
sys.path.insert(0, codes_dir2)

import basic_src.basic as basic
# import basic_src.io_function as io_function
import parameters

server="s1155090023@chpc-login01.itsc.cuhk.edu.hk"
remote_workdir='/users/s1155090023/Data/Qinghai-Tibet/entire_QTP_images/sentinel-2/autoMapping'
run_folder=os.path.join(remote_workdir, 'QTP_deeplabV3+_3')

def copy_remote_file_dir_to_local(re_path,local_dir='./'):
    os.system('scp -r '+ server + ':'+re_path + ' ' + local_dir)

def get_remote_file_list(pattern):
    command = 'ssh ' + server + ' ls ' + pattern
    result = basic.exec_command_string_output_string(command)
    # result = os.system(command)
    # print('result',type(result))

    if "No such file or directory" in result:
        basic.outputlogMessage(result)
        return False
    else:
        file_list = result.split('\n')
        return file_list


# test
# re_file_list = get_remote_file_list(run_folder +'/multi_inf_results/*.txt')
# if re_file_list is False:
#     sys.exit(1)
# for re_file in re_file_list:
#     copy_remote_file_dir_to_local(re_file)


# copy the inf_image_list.txt to local
copy_remote_file_dir_to_local(os.path.join(run_folder,'inf_image_list.txt'))
copy_remote_file_dir_to_local(os.path.join(run_folder,'para_qtp.ini'))

with open('inf_image_list.txt','r') as inf_obj:
    inf_img_list = [name.strip() for name in inf_obj.readlines()]

img_count = len(inf_img_list)
if img_count < 1:
    raise ValueError('No image in inf_image_list.txt')

done_list = []  # a list of files, e.g., 15.txt_done, which incate the task is complete
# check multi_inf_results exist, not necessary to remove it, since scp can replace files inside
outdir = 'multi_inf_results'
os.system('mkdir -p ' + outdir)

para_file = sys.argv[1]

# expr_name=$(python2 ${para_py} -p ${para_file} expr_name)
# NUM_ITERATIONS=$(python2 ${para_py} -p ${para_file} export_iteration_num)
# trail=iter${NUM_ITERATIONS}
#
# testid=$(basename $PWD)_${expr_name}_${trail}
# output=${testid}.tif

expr_name = parameters.get_string_parameters(para_file,'expr_name')
NUM_ITERATIONS = parameters.get_string_parameters(para_file,'export_iteration_num')
trail = 'iter' + NUM_ITERATIONS
testid = os.path.basename(os.getcwd()) + '_' + expr_name + '_' + trail
output = testid + '.tif'

while len(done_list) < img_count:
    re_file_list = get_remote_file_list(os.path.join(run_folder, outdir, '*.txt_done'))  # + '/multi_inf_results/*.txt_done')
    if re_file_list is False:
        basic.outputlogMessage('No completed prediction sub-images, wait one more minute ')
        time.sleep(60)  # wait one minute

    remote_done_count = len(re_file_list)
    if len(done_list) == remote_done_count:
        basic.outputlogMessage('No new completed prediction sub-images, wait one more minute ')
        time.sleep(60)  # wait one minute

    for re_task_file in re_file_list:

        base_name = os.path.basename(re_task_file)
        task_id = base_name.split('.')[0]
        done_task = os.path.join(outdir, base_name)
        if os.path.isfile(done_task):
            if base_name not in done_list:
                done_list.append(base_name)
            continue

        # copy the remote folder
        re_task_folder =  os.path.join(os.path.dirname(re_task_file), 'I'+task_id)
        local_folder = os.path.join(outdir,'I'+task_id)
        copy_remote_file_dir_to_local(re_task_folder,local_folder)

        cwd_dir = os.getcwd()
        os.chdir(local_folder)
        # gdal_merge.py, which is time-consuming
        task_out_tif = 'I' + task_id + '_' + output
        if os.path.isfile(task_out_tif) is False:
            os.system('gdal_merge.py -init 0 -n 0 -a_nodata 0 -o ' + task_out_tif + ' ' + 'I0_*.tif' )

        # gdal_polygonize.py
        task_out_shp = 'I' + task_id + '_' + testid + '.shp'
        if os.path.isfile(task_out_shp) is False:
            os.system('gdal_polygonize.py -8 '+ task_out_tif +  '-b 1 -f "ESRI Shapefile"' + task_out_shp)

        os.chdir(cwd_dir)

        # indicating it is done
        copy_remote_file_dir_to_local(re_task_file, os.path.join(outdir, base_name))
        done_list.append(base_name)


# after all done,  run exe_qtp.sh for further post-processing and merging of shape file
os.system('./exe_qtp.sh')

