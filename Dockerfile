FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as builder

COPY --from=continuumio/miniconda3:4.12.0 /opt/conda /opt/conda

ENV PATH=/opt/conda/bin:$PATH

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y git build-essential \
    ocl-icd-opencl-dev opencl-headers clinfo \
    && mkdir -p /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

RUN conda create -y -n lollms python=3.10

SHELL ["conda", "run", "-n", "lollms", "/bin/bash", "-c"]

RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

RUN git clone https://github.com/TimDettmers/bitsandbytes.git --branch 0.40.0 \
    && cd bitsandbytes \
    && CUDA_VERSION=118 make cuda11x \
    && python3 setup.py install

RUN pip3 uninstall -y llama-cpp-python \
    && CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 pip3 install llama-cpp-python==0.1.72 --no-cache-dir

RUN git clone https://github.com/ParisNeo/lollms-webui.git --branch v3.0

WORKDIR /lollms-webui

RUN pip3 install -r requirements.txt

RUN git clone https://github.com/ParisNeo/lollms_personalities_zoo.git personalities_zoo \
    && cd personalities_zoo && git checkout 643cc32d2585465ca74732f956f80dafa4c82fce

RUN git clone https://github.com/ParisNeo/lollms_bindings_zoo.git bindings_zoo \
    && cd bindings_zoo && git checkout ba6bc56520c9b24b77e0555c919de22d5e9dedbd

RUN bash -c 'for i in bindings_zoo/*/requirements.txt ; do pip3 install -r $i ; done'

RUN CT_CUBLAS=1 pip3 install ctransformers --no-binary ctransformers

RUN conda clean -afy

FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /usr/local/cuda-11.8/targets/x86_64-linux/include /usr/local/cuda-11.8/targets/x86_64-linux/include

ENV PATH=/opt/conda/bin:$PATH

COPY --from=builder /lollms-webui /lollms-webui

RUN apt-get update && apt-get upgrade -y \
    && apt-get -y install python3 build-essential git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && mkdir -p /etc/OpenCL/vendors

COPY --from=builder /etc/OpenCL/vendors/nvidia.icd /etc/OpenCL/vendors/nvidia.icd

WORKDIR /lollms-webui

#RUN mkdir -p models/{py_llama_cpp,c_transformers,llama_cpp_official,binding_template,gpt_j_m,gpt_4all,open_ai,gpt_j_a,gptq,hugging_face}

RUN mkdir /models && mkdir models && cd models && for dir in py_llama_cpp c_transformers llama_cpp_official binding_template gpt_j_m gpt_4all open_ai gpt_j_a gptq hugging_face; \
    do ln -s /models $dir; \
    done


COPY ./global_paths_cfg.yaml .

EXPOSE 9600

RUN echo "source activate lollms" >> ~/.bashrc

# Define the entrypoint
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "lollms"]
CMD ["python3", "app.py"]
