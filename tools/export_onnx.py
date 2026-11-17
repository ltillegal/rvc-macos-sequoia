import torch
from infer.lib.infer_pack.models_onnx import SynthesizerTrnMsNSFsidM

if __name__ == "__main__":
    MoeVS = True  # whether the model targets MoeVoiceStudio (formerly MoeSS)

    ModelPath = "Shiroha/shiroha.pth"  # model path
    ExportedPath = "model.onnx"  # output path
    hidden_channels = 256  # hidden channels, so 768-dim vector models also work
    cpt = torch.load(ModelPath, map_location="cpu")
    cpt["config"][-3] = cpt["weight"]["emb_g.weight"].shape[0]  # n_spk
    print(*cpt["config"])

    test_phone = torch.rand(1, 200, hidden_channels)  # hidden unit
    test_phone_lengths = torch.tensor([200]).long()  # hidden-unit length (apparently unused)
    test_pitch = torch.randint(size=(1, 200), low=5, high=255)  # fundamental frequency in Hz
    test_pitchf = torch.rand(1, 200)  # nsf pitch
    test_ds = torch.LongTensor([0])  # speaker id
    test_rnd = torch.rand(1, 192, 200)  # noise (random factor)

    device = "cpu"  # device used for export; does not affect the exported model

    net_g = SynthesizerTrnMsNSFsidM(
        *cpt["config"], is_half=False
    )  # export as fp32; fp16 would need manual memory reordering on the C++ side
    net_g.load_state_dict(cpt["weight"], strict=False)
    input_names = ["phone", "phone_lengths", "pitch", "pitchf", "ds", "rnd"]
    output_names = [
        "audio",
    ]
    # net_g.construct_spkmixmap(n_speaker)  # multi-speaker mixed-track export
    torch.onnx.export(
        net_g,
        (
            test_phone.to(device),
            test_phone_lengths.to(device),
            test_pitch.to(device),
            test_pitchf.to(device),
            test_ds.to(device),
            test_rnd.to(device),
        ),
        ExportedPath,
        dynamic_axes={
            "phone": [1],
            "pitch": [1],
            "pitchf": [1],
            "rnd": [2],
        },
        do_constant_folding=False,
        opset_version=16,
        verbose=False,
        input_names=input_names,
        output_names=output_names,
    )
