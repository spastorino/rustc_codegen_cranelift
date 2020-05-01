#![feature(core_intrinsics, generators, generator_trait, is_sorted)]

use std::arch::x86_64::*;
use std::io::Write;
use std::ops::{Generator, Shl};

fn main() {
    println!("{:?}", std::env::args().collect::<Vec<_>>());

    let mutex = std::sync::Mutex::new(());
    let _guard = mutex.lock().unwrap();

    let _ = ::std::iter::repeat('a' as u8).take(10).collect::<Vec<_>>();
    let stderr = ::std::io::stderr();
    let mut stderr = stderr.lock();

    std::thread::spawn(move || {
        println!("Hello from another thread!");
    });

    writeln!(stderr, "some {} text", "<unknown>").unwrap();

    let _ = std::process::Command::new("true").env("c", "d").spawn();

    println!("cargo:rustc-link-lib=z");

    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {});

    let _eq = LoopState::Continue(()) == LoopState::Break(());

    // Make sure ByValPair values with differently sized components are correctly passed
    map(None::<(u8, Box<Instruction>)>);

    println!("{}", 2.3f32.exp());
    println!("{}", 2.3f32.exp2());
    println!("{}", 2.3f32.abs());
    println!("{}", 2.3f32.sqrt());
    println!("{}", 2.3f32.floor());
    println!("{}", 2.3f32.ceil());
    println!("{}", 2.3f32.min(1.0));
    println!("{}", 2.3f32.max(1.0));
    println!("{}", 2.3f32.powi(2));
    println!("{}", 2.3f32.log2());
    assert_eq!(2.3f32.copysign(-1.0), -2.3f32);
    println!("{}", 2.3f32.powf(2.0));

    assert_eq!(-128i8, (-128i8).saturating_sub(1));
    assert_eq!(127i8, 127i8.saturating_sub(-128));
    assert_eq!(-128i8, (-128i8).saturating_add(-128));
    assert_eq!(127i8, 127i8.saturating_add(1));

    assert_eq!(0b0000000000000000000000000010000010000000000000000000000000000000_0000000000100000000000000000000000001000000000000100000000000000u128.leading_zeros(), 26);
    assert_eq!(0b0000000000000000000000000010000000000000000000000000000000000000_0000000000000000000000000000000000001000000000000000000010000000u128.trailing_zeros(), 7);

    let _d = 0i128.checked_div(2i128);
    let _d = 0u128.checked_div(2u128);
    assert_eq!(1u128 + 2, 3);

    assert_eq!(0b100010000000000000000000000000000u128 >> 10, 0b10001000000000000000000u128);
    assert_eq!(0xFEDCBA987654321123456789ABCDEFu128 >> 64, 0xFEDCBA98765432u128);
    assert_eq!(0xFEDCBA987654321123456789ABCDEFu128 as i128 >> 64, 0xFEDCBA98765432i128);

    let tmp = 353985398u128;
    assert_eq!(tmp * 932490u128, 330087843781020u128);

    let tmp = -0x1234_5678_9ABC_DEF0i64;
    assert_eq!(tmp as i128, -0x1234_5678_9ABC_DEF0i128);

    // Check that all u/i128 <-> float casts work correctly.
    let houndred_u128 = 100u128;
    let houndred_i128 = 100i128;
    let houndred_f32 = 100.0f32;
    let houndred_f64 = 100.0f64;
    assert_eq!(houndred_u128 as f32, 100.0);
    assert_eq!(houndred_u128 as f64, 100.0);
    assert_eq!(houndred_f32 as u128, 100);
    assert_eq!(houndred_f64 as u128, 100);
    assert_eq!(houndred_i128 as f32, 100.0);
    assert_eq!(houndred_i128 as f64, 100.0);
    assert_eq!(houndred_f32 as i128, 100);
    assert_eq!(houndred_f64 as i128, 100);

    // Test signed 128bit comparing
    let max = usize::MAX as i128;
    if 100i128 < 0i128 || 100i128 > max {
        panic!();
    }

    test_checked_mul();

    let _a = 1u32 << 2u8;

    let empty: [i32; 0] = [];
    assert!(empty.is_sorted());

    println!("{:?}", std::intrinsics::caller_location());

    #[derive(Copy, Clone)]
    enum Nums {
        NegOne = -1,
    }

    let kind = Nums::NegOne;
    assert_eq!(-1i128, kind as i128);

    if u8::shl(1, 9) != 2_u8 {
        unsafe { std::intrinsics::abort(); }
    }

    /*const STR: &'static str = "hello";
    fn other_casts() -> *const str {
        STR as *const str
    }
    if other_casts() != STR as *const str {
        unsafe { std::intrinsics::abort(); }
    }*/
}

fn test_checked_mul() {
    let u: Option<u8> = u8::from_str_radix("1000", 10).ok();
    assert_eq!(u, None);

    assert_eq!(1u8.checked_mul(255u8), Some(255u8));
    assert_eq!(255u8.checked_mul(255u8), None);
    assert_eq!(1i8.checked_mul(127i8), Some(127i8));
    assert_eq!(127i8.checked_mul(127i8), None);
    assert_eq!((-1i8).checked_mul(-127i8), Some(127i8));
    assert_eq!(1i8.checked_mul(-128i8), Some(-128i8));
    assert_eq!((-128i8).checked_mul(-128i8), None);

    assert_eq!(1u64.checked_mul(u64::max_value()), Some(u64::max_value()));
    assert_eq!(u64::max_value().checked_mul(u64::max_value()), None);
    assert_eq!(1i64.checked_mul(i64::max_value()), Some(i64::max_value()));
    assert_eq!(i64::max_value().checked_mul(i64::max_value()), None);
    assert_eq!((-1i64).checked_mul(i64::min_value() + 1), Some(i64::max_value()));
    assert_eq!(1i64.checked_mul(i64::min_value()), Some(i64::min_value()));
    assert_eq!(i64::min_value().checked_mul(i64::min_value()), None);
}

#[derive(PartialEq)]
enum LoopState {
    Continue(()),
    Break(())
}

pub enum Instruction {
    Increment,
    Loop,
}

fn map(a: Option<(u8, Box<Instruction>)>) -> Option<Box<Instruction>> {
    match a {
        None => None,
        Some((_, instr)) => Some(instr),
    }
}
