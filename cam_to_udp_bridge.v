`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: cam_to_udp_bridge
// Description: 
// 1. Captures a line of video data from a camera.
// 2. Prepends a 2-byte line number (little-endian).
// 3. Crosses clock domains (camera -> UDP) using an internal FIFO.
// 4. Feeds the resulting packet payload to the UDP stack application interface.
//////////////////////////////////////////////////////////////////////////////////
module cam_to_udp_bridge(
    //========= Camera Interface (Input) ==========
    input                   cam_clk,          // Camera pixel clock (cam_pclk)
    input                   cam_rst_n,        // Active-low reset for camera clock domain
    input                   cam_href,         // Camera H-Sync (line valid)
    input                   cam_vsync,        // Camera V-Sync (frame valid)
    input                   cam_data_valid,   // Pixel valid signal
    input      [15:0]       cam_data,         // Pixel data (RGB565)

    //========= UDP Stack Interface (Handshake) ==========
    input                   udp_clk,          // UDP core clock
    input                   udp_rst_n,        // Active-low reset for UDP clock domain
    input                   udp_tx_ready,     // From UDP stack: '1' indicates ready for a new packet

    output reg              app_tx_request,   // To UDP stack: Pulse to request a send
    output reg   [15:0]     app_tx_data_length, // To UDP stack: Total payload length in bytes
    output reg   [7:0]      app_tx_data,      // To UDP stack: Data byte
    output reg              app_tx_data_valid // To UDP stack: Valid strobe for app_tx_data
);

//----------------------------------------------------------------
// Parameters
//----------------------------------------------------------------
localparam IMAGE_WIDTH  = 640;
localparam HEADER_BYTES = 2;
localparam PIXEL_BYTES  = IMAGE_WIDTH * 2;
localparam PAYLOAD_LEN  = PIXEL_BYTES + HEADER_BYTES; // 1280 + 2 = 1282 bytes

//----------------------------------------------------------------
// Internal Signals
//----------------------------------------------------------------
// FIFO signals
wire            fifo_wr_en;
wire    [7:0]   fifo_wr_data;
wire            fifo_full;
wire            fifo_rd_en;
wire    [7:0]   fifo_rd_data;
wire            fifo_empty;
wire    [10:0]  fifo_rd_count;

// Write-side (Camera Domain) logic
reg             cam_href_dly;
wire            cam_href_posedge;
reg     [9:0]   line_counter;     // For 480 lines (0-479)
reg     [10:0]  pixel_counter;    // For 640 pixels (0-639)
reg     [15:0]  line_num_reg;

// Read-side (UDP Domain) logic
reg             app_tx_sending;   // Flag to indicate a packet is being sent
reg     [10:0]  bytes_sent_counter;

//----------------------------------------------------------------
//----------------------------------------------------------------
// Read Side Logic (UDP Clock Domain) - REVISED FOR FASTER RESPONSE
//----------------------------------------------------------------
// FSM states
localparam  RD_IDLE = 1'b0,
            RD_SEND = 1'b1;

reg         rd_state;
reg         app_tx_sending;       // Flag to indicate a packet is being sent
reg [10:0]  bytes_sent_counter;

assign fifo_rd_en = (rd_state == RD_SEND) && !fifo_empty;

// FSM for reading from FIFO and handshaking with UDP core
always @(posedge udp_clk or negedge udp_rst_n) begin
    if (!udp_rst_n) begin
        rd_state <= RD_IDLE;
        app_tx_request <= 1'b0;
        app_tx_data_valid <= 1'b0;
        bytes_sent_counter <= 0;
        app_tx_data_length <= 0;
    end else begin
        // Default assignments for outputs
        app_tx_request <= 1'b0;
        app_tx_data_valid <= fifo_rd_en; // Directly connect valid to read enable for low latency

        case (rd_state)
            RD_IDLE: begin
                // Wait until we have a full packet and the UDP core is ready
                if (udp_tx_ready && (fifo_rd_count >= PAYLOAD_LEN)) begin
                    app_tx_request <= 1'b1;       // Assert request for one cycle
                    app_tx_data_length <= PAYLOAD_LEN; // Present length at the same time
                    bytes_sent_counter <= 0;
                    rd_state <= RD_SEND;
                end else begin
                    rd_state <= RD_IDLE;
                end
            end

            RD_SEND: begin
                if (fifo_rd_en) begin
                    if (bytes_sent_counter == PAYLOAD_LEN - 1) begin
                        bytes_sent_counter <= 0;
                        rd_state <= RD_IDLE; // Last byte sent, return to IDLE
                    end else begin
                        bytes_sent_counter <= bytes_sent_counter + 1;
                        rd_state <= RD_SEND;
                    end
                end else begin
                    // Wait if FIFO becomes empty mid-packet (should not happen in this design)
                    rd_state <= RD_SEND;
                end
            end
            
            default: begin
                rd_state <= RD_IDLE;
            end
        endcase
    end
end

// Registered data output to avoid combinatorial paths to other modules
always @(posedge udp_clk) begin
    if (fifo_rd_en) begin
        app_tx_data <= fifo_rd_data;
    end
end


//----------------------------------------------------------------
// Instantiation of Asynchronous FIFO (Anlogic IP Core)
// ... The FIFO instantiation remains the same ...
//----------------------------------------------------------------
//----------------------------------------------------------------
// Instantiation of Asynchronous FIFO (Anlogic IP Core)
// 
// **重要**: 请确保您生成的FIFO具有以下参数:
// 1. Clock Mode: ASYNC (异步)
// 2. Write/Read Width: 8
// 3. Write/Read Depth: 2048 (这会使 rdusedw 变为 11 位)
//----------------------------------------------------------------
async_fifo_2048x8 u_fifo (
  // Write Port (Camera Clock Domain)
  .clkw     (cam_clk),        // 写入时钟 (来自摄像头)
  .wrst     (~cam_rst_n),     // 写入复位 (高电平有效, 由我们的低有效复位取反)
  .di       (fifo_wr_data),   // 8-bit 数据输入
  .we       (fifo_wr_en),     // 写入使能

  // Read Port (UDP Clock Domain)
  .clkr     (udp_clk),        // 读取时钟 (来自UDP核心)
  .rrst     (~udp_rst_n),     // 读取复位 (高电平有效)
  .dout     (fifo_rd_data),   // 8-bit 数据输出
  .re       (fifo_rd_en),     // 读取使能

  // Status Flags
  .full_flag  (fifo_full),    // 满标志
  .empty_flag (fifo_empty),   // 空标志
  .rdusedw    (fifo_rd_count), // **关键**: 读侧数据计数 (应为 11-bit, [10:0])

  // Unused Ports (if they exist, otherwise delete)
  .aempty(),
  .afull(),
  .valid(),
  .overflow(),
  .underflow(),
  .wr_success(),
  .wrusedw(),
  .wr_rst_done(),
  .rd_rst_done()
);
endmodule