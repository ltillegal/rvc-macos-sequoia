import soundfile

from ..infer.lib.infer_pack.onnx_inference import OnnxRVC

hop_size = 512
sampling_rate = 40000  # sample rate
f0_up_key = 0  # transpose
sid = 0  # speaker id
f0_method = "dio"  # F0 extraction method
model_path = "ShirohaRVC.onnx"  # full path to the model
vec_name = (
    "vec-256-layer-9"  # expanded to f"pretrained/{vec_name}.onnx"; needs an ONNX vec model
)
wav_path = "123.wav"  # input path or ByteIO instance
out_path = "out.wav"  # output path or ByteIO instance

model = OnnxRVC(
    model_path, vec_path=vec_name, sr=sampling_rate, hop_size=hop_size, device="cuda"
)

audio = model.inference(wav_path, sid, f0_method=f0_method, f0_up_key=f0_up_key)

soundfile.write(out_path, audio, sampling_rate)
