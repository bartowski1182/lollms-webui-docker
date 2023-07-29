FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as builder

COPY --from=continuumio/miniconda3:4.12.0 /opt/conda /opt/conda

ENV PATH=/opt/conda/bin:$PATH

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y git build-essential \
    ocl-icd-opencl-dev opencl-headers clinfo \
    && mkdir -p /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

RUN conda create -y -n lollms python=3.10.9

SHELL ["conda", "run", "-n", "lollms", "/bin/bash", "-c"]

RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

RUN git clone https://github.com/TimDettmers/bitsandbytes.git --branch 0.41.0 \
    && cd bitsandbytes \
    && CUDA_VERSION=118 make cuda11x \
    && python3 setup.py install

RUN pip3 uninstall -y llama-cpp-python \
    && CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 pip3 install llama-cpp-python==0.1.77 --no-cache-dir

RUN CT_CUBLAS=1 pip3 install ctransformers --no-binary ctransformers

RUN git clone https://github.com/ParisNeo/lollms-webui.git --branch v3.5

WORKDIR /lollms-webui

RUN pip3 install -r requirements.txt

RUN pip3 install scipy auto_gptq

RUN git clone https://github.com/ParisNeo/lollms_personalities_zoo.git personalities_zoo \
    && cd personalities_zoo && git checkout 3eee2d3deadfd8735e319f9a3ba9766cf056f16e

RUN git clone https://github.com/ParisNeo/lollms_bindings_zoo.git bindings_zoo \
    && cd bindings_zoo && git checkout 6337cb22d1fab3edb8f7badb771c3c0da12173e3

RUN bash -c 'for i in bindings_zoo/*/requirements.txt ; do pip3 install -r $i ; done'

RUN conda clean -afy

FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /usr/local/cuda-11.8/targets/x86_64-linux/include /usr/local/cuda-11.8/targets/x86_64-linux/include
COPY --from=builder /etc/OpenCL/vendors/nvidia.icd /etc/OpenCL/vendors/nvidia.icd

ENV PATH=/opt/conda/bin:/usr/local/cuda/lib64/:$PATH

COPY --from=builder /lollms-webui /lollms-webui


# Setting frontend to noninteractive to avoid getting locked on keyboard input
ENV DEBIAN_FRONTEND=noninteractive

# Installing all the packages we need and updating cuda-keyring
RUN apt-get -y update && apt-get -y install wget && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb \
    && dpkg -i cuda-keyring_1.0-1_all.deb && apt-get update && apt-get upgrade -y \
    && apt-get -y install python3 build-essential git \
    && mkdir -p /etc/OpenCL/vendors \
    && apt-get -y install cuda-11.8 && apt-get -y install cuda-11.8 \
    && systemctl enable nvidia-persistenced \
    && cp /lib/udev/rules.d/40-vm-hotadd.rules /etc/udev/rules.d \
    && sed -i '/SUBSYSTEM=="memory", ACTION=="add"/d' /etc/udev/rules.d/40-vm-hotadd.rules \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /lollms-webui

RUN mkdir /models && mkdir models && cd models && for dir in py_llama_cpp c_transformers llama_cpp_official binding_template gpt_j_m gpt_4all open_ai gpt_j_a gptq hugging_face; \
    do ln -s /models $dir; \
    done

COPY ./global_paths_cfg.yaml .

# Injecting a fix to properly load personalities
RUN sed -i "/language = request.args.get('language')/a \        if language is None:\n            language = 'english'" app.py

EXPOSE 9600

RUN echo "source activate lollms" >> ~/.bashrc

# Define the entrypoint
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "lollms"]
CMD ["python3", "app.py"]
