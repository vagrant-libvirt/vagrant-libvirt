class ByteNumber < Numeric
    def initialize(int)
        @int = int
    end

    def to_s
        @int.to_s
    end

    def to_i
        @int
    end

    def to_f
        @int.to_f
    end

    def to_B
        to_i
    end

    def to_KB
        _compute_unit_to_n_kilo(1)
    end

    def to_MB
        _compute_unit_to_n_kilo(2)
    end

    def to_GB
        _compute_unit_to_n_kilo(3)
    end

    def coerce(other)
        to_i.coerce(other)
    end

    def <=>(other)
        to_i <=> other
    end

    def +(other)
        to_i + other
    end

    def -(other)
        to_i - other
    end

    def *(other)
        to_i * other
    end

    def /(other)
        to_i / other
    end

    def pow(n)
        self.class.new(to_i ** n)
    end

    def self.from_GB(value)
        self.new(value*(1024**3))
    end

    private
    def _compute_unit_to_n_kilo(n=0)
        (to_f/(1024 ** n)).ceil
    end
end
