open("test.S", "w") do f
    for i = 0:0xffff
        print(f, ".section .text$i\nfoo$i:\nret\n")
    end
end
