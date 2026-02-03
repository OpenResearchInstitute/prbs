import numpy as np

class prbs_generator():
    def __init__(self, seed=0x8E75_89FD, polynomial=0x4800_0000, error_mask=1, data_width=1, generator_width=31):
        # Remove super() call - not inheriting from anything
        self.seed = seed
        self.polynomial = polynomial  # Store all parameters
        self.error_mask = error_mask
        self.data_width = data_width
        self.generator_width = generator_width
        self.lfsr = np.uint32(seed)
    
    def init(self):
        self.lfsr = np.uint32(self.seed)
    
    def xor_reduce(self, value):
        """XOR reduce - equivalent to parity calculation"""
        return bin(value).count('1') & 1
    
    def bit(self):
        """Generate data_width bits from the PRBS generator"""
        output_bits = []
        for i in range(self.data_width):  # Fix: "for i in range(...)"
            # Get feedback bit
            feedback = self.xor_reduce(self.lfsr & self.polynomial)  # Fix: use & not &&
            
            # Output bit is typically the MSB
            output_bit = (self.lfsr >> (self.generator_width - 1)) & 1
            
            # Shift and insert feedback at LSB
            self.lfsr = np.uint32((self.lfsr << 1) | feedback)  # Fix: use | for OR
            
            # Mask to generator width
            self.lfsr &= (1 << self.generator_width) - 1
            
            output_bits.append(output_bit)
        
        # Return single bit or packed value depending on data_width
        if self.data_width == 1:
            return output_bits[0]
        else:
            # Pack bits into integer
            return sum(bit << i for i, bit in enumerate(output_bits))

class prbs_monitor():

		def __init__(self, seed=1):
			super(prbs_monitor, self).__init__()

			self.seed = seed
			self.lfsr = seed

		def init(self):
			self.lfsr = self.seed

