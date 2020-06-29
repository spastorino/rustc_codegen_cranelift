fn main() {
    let options = [1u128];
    match options[0] {
        1 => (),
        0 => loop {},
        v => panic(v),
    };
}

fn panic(v: u128) -> !{
    panic!("{}", v)
}
