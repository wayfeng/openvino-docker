FROM alpine:3.12 as ov_builder
WORKDIR /home
#RUN printf 'http://dl-cdn.alpinelinux.org/alpine/v3.12/main\n\
#http://dl-cdn.alpinelinux.org/alpine/v3.12/community\n\
#http://dl-cdn.alpinelinux.org/alpine/edge/testing' > /etc/apk/repositories

RUN apk update && \
	apk add build-base ca-certificates cmake curl linux-headers \
	        gcc g++ git python3 python3-dev wget zlib-dev

RUN git clone --depth 1 -b 4.5.0-openvino https://github.com/opencv/opencv.git && \
	git clone --depth 1 -b 4.5.0 https://github.com/opencv/opencv_contrib.git && \
	cd opencv && mkdir -p build && cd build && \
	cmake -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules .. && \
	make -j$(nproc) && make install

RUN git clone --depth 1 -b v2020.3 https://github.com/oneapi-src/oneTBB.git build_tbb && \
	cd build_tbb && make -j$(nproc) tbb && \
	mkdir -p /usr/local/tbb/lib && \
	cp -r include /usr/local/tbb/ && \
	cp -r cmake /usr/local/tbb/ && \
	cp build/linux_intel64_gcc_cc9.3.0_libc_kernel5.4.0_release/libtbb.so /usr/local/tbb/lib && \
	cp build/linux_intel64_gcc_cc9.3.0_libc_kernel5.4.0_release/libtbb.so.2 /usr/local/tbb/lib

RUN git clone --depth 1 -b 2021.1 https://github.com/openvinotoolkit/openvino.git && \
	cd openvino && git submodule update --init && \
	mkdir build && cd build && \
	cmake -DENABLE_MYRIAD=OFF -DENABLE_VPU=OFF -DENABLE_OPENCV=OFF \
		-DENABLE_CLDNN=OFF -DENABLE_GNA=OFF -DTBBROOT=/usr/local/tbb \
		-DPYTHON_EXECUTABLE=/usr/bin/python3 .. && \
	make -j$(nproc) && \
	cp -r /home/openvino/bin/intel64/Release /home/

FROM alpine:3.12
WORKDIR /opt/openvino

ENV LD_LIBRARY_PATH=/opt/openvino/lib
COPY --from=ov_builder /usr/local /usr/local
RUN apk update && apk add libstdc++
RUN mkdir -p /opt/openvino/lib
COPY --from=ov_builder /home/Release/classification_sample_async /opt/openvino
COPY --from=ov_builder /home/Release/lib/libformat_reader.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libinference_engine_ir_reader.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libinference_engine_legacy.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libinference_engine_lp_transformations.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libinference_engine.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libinference_engine_transformations.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libMKLDNNPlugin.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/libngraph.so /opt/openvino/lib
COPY --from=ov_builder /home/Release/lib/plugins.xml /opt/openvino/lib
COPY --from=ov_builder /usr/local/tbb/lib/libtbb.so.2 /opt/openvino/lib
