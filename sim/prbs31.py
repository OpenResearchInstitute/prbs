

class lfsr_rtl:

    def __init__(self, start, length, poly, mask):
        self.lfsr = start
        self.len  = length
        self.mask = mask
        self.poly = poly
        self.count0 = 0
        self.count1 = 0

    def step(self):
        lfsr_masked = self.lfsr & self.poly
        newbit = self.xor_reduce(lfsr_masked, self.len)
        self.lfsr = ((self.lfsr << 1) | newbit) & self.mask

        if newbit == 0:
            self.count0 += 1
        else:
            self.count1 += 1

    def xor_reduce(self, data, len):
        ldata = data
        res = data & 1
        for i in range(len):
            ldata = ldata >> 1
            res = res ^ (ldata & 1)
        return res


class lfsr_example:

    def __init__(self, start, bits, mask):
        self.lfsr = start
        self.mask = mask
        self.poly_bits = bits
        self.count0 = 0
        self.count1 = 0

    def step(self):
        newbit = 0
        for bit in self.poly_bits:
            newbit ^= ((self.lfsr >> bit) & 1)
        newbit = newbit & 1
        self.lfsr = ((self.lfsr << 1) | newbit) & self.mask

        if newbit == 0:
            self.count0 += 1
        else:
            self.count1 += 1

if __name__ == '__main__':
    # Execute when the module is not initialized from an import statement.

    start = 0x2
    
    lfsr = start
    count = 0
    
    lfsr_length = 31
    poly_bits = (30, 27)
    
    lfsr_mask = 2**lfsr_length-1
    poly_mask = 0
    
    for bit in poly_bits:
        poly_mask += 1 << bit
    
    count_zeros = 0
    count_ones = 0


    lfsr0 = lfsr_example(start, poly_bits, lfsr_mask)
    lfsr1 = lfsr_rtl(start, lfsr_length, poly_mask, lfsr_mask)


    while True:
    
        lfsr0.step()
        lfsr1.step()
    
        count += 1
    
        if count % 0x100_0000 == 0:
            print(hex(count))
    
        if lfsr0.lfsr != lfsr1.lfsr:
            print("lfsr mismatch")
            break
    
        if lfsr0.lfsr == start or lfsr1.lfsr == start:
            print("expected repition period is", hex(lfsr_mask))
            print("repetition period is ", hex(count))
            break
    
    print("LFSR0 Zeros: ", lfsr0.count0)
    print("LFSR0 Ones: ", lfsr0.count1)
    print("LFSR1 Zeros: ", lfsr1.count0)
    print("LFSR1 Ones: ", lfsr1.count1)