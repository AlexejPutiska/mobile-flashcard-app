// socket.js
let io;

module.exports = {
  init: (server) => {
    const { Server } = require('socket.io');
    io = new Server(server, {
      cors: {
        origin: '*',
      },
    });

    io.on('connection', (socket) => {
      console.log('📡 WebSocket klient pripojený:', socket.id);
    });

    return io;
  },
  getIO: () => {
    if (!io) {
      throw new Error('Socket.io nie je inicializovaný!');
    }
    return io;
  },
};
