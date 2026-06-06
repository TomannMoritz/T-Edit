// --------------------------------------------------
// Editor configuration
// --------------------------------------------------

pub const Config = struct {
    text_width : u8,
    text_height : u8,
    offset_vertical : u8,
    offset_horizontal : u8,

    pub fn setup_config() Config {
        // TODO: customize configuration (load config file)
        const doc_config = Config{
            .text_height = 10,
            .text_width = 25,
            .offset_vertical = 1,
            .offset_horizontal = 2,
        };

        return doc_config;
    }
};


