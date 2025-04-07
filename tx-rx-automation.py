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
        os.system(f'echo "oslab0slab" | sudo -kS tshark -r {input_file} -qz io,stat,1,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | grep -P "\\d+\\.?\\d*\\s+<>\\s+|Interval +\\|" | tr -d " " | tr "|" "," | sed -E \'s/<>/,/; s/(^,|,$)//g; ; s/BYTES,BYTES/{task}{index}_tx,{task}{index}_rx/g; s/Interval/Time0,Time/g\' | cut -d, -f1 --complement >> {moved_file}')
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
        "id0_cifar10_alexnet_sync_batch8192",
        "id10_cifar10_resnet110_sync_batch4096",
        "id11_cifar10_resnet110_sync_batch8192",
        "id12_cifar10_resnet44_sync_batch2048",
        "id13_cifar10_resnet44_sync_batch4096",
        "id14_cifar10_resnet44_sync_batch8192",
        "id15_cifar10_resnet56_sync_batch2048",
        "id16_cifar10_resnet56_sync_batch4096",
        "id17_cifar10_resnet56_sync_batch8192",
        "id18_imagenet_googlenet_sync_batch512",
        "id19_imagenet_googlenet_sync_batch1024",
        "id1_cifar10_alexnet_sync_batch16384",
        "id20_imagenet_googlenet_sync_batch2048",
        "id21_imagenet_inception3_sync_batch128",
        "id22_imagenet_inception3_sync_batch256",
        "id23_imagenet_inception3_sync_batch512",
        "id24_imagenet_resnet50_sync_batch256",
        "id25_imagenet_resnet50_sync_batch512",
        "id26_imagenet_resnet50_sync_batch1024",
        "id27_imagenet_vgg16_sync_batch256",
        "id28_imagenet_vgg16_sync_batch512",
        "id29_imagenet_vgg16_sync_batch1024",
        "id2_cifar10_alexnet_sync_batch32768",
        "id30_squad_bert_sync_batch8",
        "id31_squad_bert_sync_batch16",
        "id32_squad_bert_sync_batch32",
        "id33_squad_bertl_sync_batch8",
        "id34_squad_bertl_sync_batch16",
        "id35_squad_bertl_sync_batch32",
        "id36_squad_gpt2_sync_batch8",
        "id37_squad_gpt2_sync_batch16",
        "id38_squad_gpt2_sync_batch32",
        "id39_squad_gpt2l_sync_batch8",
        "id3_cifar10_densenet100_k12_sync_batch256",
        "id40_squad_gpt2l_sync_batch16",
        "id41_squad_gpt2l_sync_batch32",
        "id42_squad_gpt2m_sync_batch8",
        "id43_squad_gpt2m_sync_batch16",
        "id44_squad_gpt2m_sync_batch32",
        "id45_squad_gpt2xl_sync_batch8",
        "id46_squad_gpt2xl_sync_batch16",
        "id47_squad_gpt2xl_sync_batch32",
        "id4_cifar10_densenet100_k12_sync_batch512",
        "id5_cifar10_densenet100_k12_sync_batch1024",
        "id6_cifar10_densenet40_k12_sync_batch2048",
        "id7_cifar10_densenet40_k12_sync_batch4096",
        "id8_cifar10_densenet40_k12_sync_batch8192",
        "id9_cifar10_resnet110_sync_batch2048"
    ]
    pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())

    strategy = 'data'
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
