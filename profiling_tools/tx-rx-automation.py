import os
import argparse
import multiprocessing
from functools import partial

def make_csv(job_name, path):
    file_list = os.listdir(os.path.join(path, job_name))
    net_file_list = [file for file in file_list if file.endswith("network.pcap")]
    #net_file_list = [file for file in file_list if file.endswith("csv")]
    print('net_filelist: ', net_file_list)

    for file in net_file_list:
        ip = file.split('_')[-2]
        index = file.split('_')[-3]
        task = file.split('_')[-4]
        input_file = os.path.join(*[path, job_name, file])
        #output_file = os.path.join(*[path, job_name, f"{job_name}_{task}_{index}_{ip}_network.csv"])
        moved_file = os.path.join('./ar_csv', f"{job_name}_{task}_{index}_{ip}_network.csv")

        #os.system(f'echo "oslab0slab" | sudo -kS tshark -r {input_file} -qz io,stat,1,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | grep -P "\\d+\\.?\\d*\\s+<>\\s+|Interval +\\|" | tr -d " " | tr "|" "," | sed -E \'s/<>/,/; s/(^,|,$)//g; ; s/BYTES,BYTES/{task}{index}_tx,{task}{index}_rx/g; s/Interval/Time0,Time/g\' | cut -d, -f1 --complement >> {output_file}')
        os.system(f'echo "tjdus_981104!" | sudo -kS tshark -r {input_file} -qz io,stat,1,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | grep -E "\\d+\\.?\\d*\\s+<>\\s+|Interval +\\|" | tr -d " " | tr "|" "," | sed -E \'s/<>/,/; s/(^,|,$)//g; ; s/BYTES,BYTES/{task}{index}_tx,{task}{index}_rx/g; s/Interval/Time0,Time/g\' | cut -d, -f2- >> {moved_file}')
        #os.system(f'echo "oslab0slab" | sudo -kS rm -rf {input_file}')
        #os.system(f'echo "oslab0slab" | sudo mv {input_file} {moved_file}')

def process_job_name(job_name, sched_path):
    print(f'Processing {job_name} in {sched_path}...')
    make_csv(job_name, sched_path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='./')
    args = parser.parse_args()
    path = args.path

    job_names = [
        "id1_cifar10_densenet100_k12_sync_batch256",
        "id10_cifar10_alexnet_sync_batch16384",
        "id11_cifar10_alexnet_sync_batch32768",
        "id13_cifar10_resnet110_sync_batch2048",
        "id14_cifar10_resnet110_sync_batch4096",
        "id15_cifar10_resnet110_sync_batch8192",
        "id17_cifar10_resnet44_sync_batch2048",
        "id18_cifar10_resnet44_sync_batch4096",
        "id19_cifar10_resnet44_sync_batch8192",
        "id2_cifar10_densenet100_k12_sync_batch512",
        "id21_imagenet_googlenet_sync_batch512",
        "id22_imagenet_googlenet_sync_batch1024",
        "id23_imagenet_googlenet_sync_batch2048",
        "id25_imagenet_inception3_sync_batch128",
        "id26_imagenet_inception3_sync_batch256",
        "id27_imagenet_inception3_sync_batch512",
        "id29_cifar10_densenet100_k12_sync_batch256",
        "id3_cifar10_densenet100_k12_sync_batch1024",
        "id30_cifar10_densenet100_k12_sync_batch512",
        "id31_cifar10_densenet100_k12_sync_batch1024",
        "id33_cifar10_densenet40_k12_sync_batch2048",
        "id34_cifar10_densenet40_k12_sync_batch4096",
        "id35_cifar10_densenet40_k12_sync_batch8192",
        "id37_cifar10_alexnet_sync_batch8192",
        "id38_cifar10_alexnet_sync_batch16384",
        "id39_cifar10_alexnet_sync_batch32768",
        "id41_cifar10_resnet110_sync_batch2048",
        "id42_cifar10_resnet110_sync_batch4096",
        "id43_cifar10_resnet110_sync_batch8192",
        "id45_cifar10_resnet44_sync_batch2048",
        "id46_cifar10_resnet44_sync_batch4096",
        "id47_cifar10_resnet44_sync_batch8192",
        "id49_imagenet_googlenet_sync_batch512",
        "id5_cifar10_densenet40_k12_sync_batch2048",
        "id50_imagenet_googlenet_sync_batch1024",
        "id51_imagenet_googlenet_sync_batch2048",
        "id53_imagenet_inception3_sync_batch128",
        "id54_imagenet_inception3_sync_batch256",
        "id55_imagenet_inception3_sync_batch512",
        "id6_cifar10_densenet40_k12_sync_batch4096",
        "id7_cifar10_densenet40_k12_sync_batch8192",
        "id9_cifar10_alexnet_sync_batch8192"
    ]
    pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())

    strategy = 'allreduce'
    sched_path = os.path.join(path, strategy)
    print(f'Processing {sched_path}...')

    # Use partial to create a function with fixed sched_path
    process_job_name_partial = partial(process_job_name, sched_path=sched_path)

    # Map the function to all job_names in parallel
    pool.map(process_job_name_partial, job_names)

    pool.close()
    pool.join()

if __name__ == '__main__':
    main()
