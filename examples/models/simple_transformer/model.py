import torch
import torch.nn as nn
from ..model_base import EagerModelBase
import logging

class simpleEncoder(nn.Module):
    def __init__(self, cfg: dict={'':0}, pretrained_weights=True) -> None:
        super().__init__()
        self.transformer = nn.TransformerEncoderLayer(
            d_model=cfg.get('embedding_dim', 16),
            nhead=cfg.get('num_heads', 2),
            dim_feedforward=cfg.get('mlp_dim', 64),
            dropout=cfg.get('dropout', 0.1),
            activation=cfg.get('activation', 'relu'),
            norm_first=True # PreNorm
        )
        if pretrained_weights:
            self.load_state_dict(torch.load("/home/juan/execuTorch/executorch/examples/models/simple_transformer/simple_encoder.pth", weights_only=True))
    
    def forward(self, x: torch.Tensor) -> torch.Tensor: 
        x = self.transformer(x)
        return x


class SimpleEncoderModel(EagerModelBase):
    def __init__(self):
        pass

    def get_eager_model(self) -> torch.nn.Module:

        logging.info("Loading simple transformer encoder layer")
        m = simpleEncoder()
        logging.info("Loading simple transformer encoder layer")
        return m

    def get_example_inputs(self):
        # exampleInput = (torch.load('/home/juan/execuTorch/executorch/examples/models/simple_transformer/fp32_normalD_input_tensor.pt'))
        # return (exampleInput,)
        return torch.load('/home/juan/execuTorch/cct_model/fp32_normalD_input_tensor_seed-101.pt')

if __name__ == "__main__":
    # Example usage
    m = simpleEncoder()
    m.eval()

