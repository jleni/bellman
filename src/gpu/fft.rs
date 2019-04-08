extern crate ocl;

use self::ocl::{ProQue, Buffer};
use self::ocl::prm::Ulong4;
use pairing::bls12_381::Fr;

static KERNEL_SRC : &str = include_str!("fft.cl");

pub struct Kernel {
    proque: ProQue,
    fft_buffer: Buffer<Ulong4>
}

pub fn create_kernel(n: u32) -> Kernel {
    let pq = ProQue::builder().src(KERNEL_SRC).dims(n).build().expect("Cannot create kernel!");
    let buffer = pq.create_buffer::<Ulong4>().expect("Cannot allocate buffer!");
    Kernel { proque: pq, fft_buffer: buffer }
}

impl Kernel {
    pub fn fft(&mut self, a: &mut [Fr], omega: &Fr, lgn: u32) -> ocl::Result<()> {
        fn bitreverse(mut n: u32, l: u32) -> u32 {
            let mut r = 0;
            for _ in 0..l {
                r = (r << 1) | (n & 1);
                n >>= 1;
            }
            r
        }


        let ta = unsafe { std::mem::transmute::<&mut [Fr], &mut [Ulong4]>(a) };
        for k in 0..(a.len() as u32) {
            let rk = bitreverse(k, lgn);
            if k < rk {
                ta.swap(rk as usize, k as usize);
            }
        }

        let tomega = *(unsafe { std::mem::transmute::<&Fr, &Ulong4>(omega) });

        let mut vec = vec![Ulong4::zero(); self.fft_buffer.len()];
        for i in 0..self.fft_buffer.len() { vec[i] = ta[i]; }

        self.fft_buffer.write(&vec).enq()?;

        for lgm in 0..lgn {

            let kernel = self.proque.kernel_builder("fftstep")
                .arg(&self.fft_buffer)
                .arg(ta.len() as u32)
                .arg(lgn as u32)
                .arg(tomega)
                .arg(lgm)
                .build()?;

            unsafe { kernel.enq()?; }
        }

        self.fft_buffer.read(&mut vec).enq()?;

        for i in 0..a.len() { ta[i] = vec[i]; }
        Ok(())
    }
}
