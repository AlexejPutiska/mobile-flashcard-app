const express = require('express');
const router = express.Router();
const db = require('../db');


router.get('/', async (req, res) => {
  const { userId } = req.query;
  try {
    const result = await db.query(
      'SELECT * FROM Flashcard_Set WHERE user_id = $1',
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Chyba pri načítaní setov' });
  }
});


router.post('/', async (req, res) => {
  const { userId, name, isPublic } = req.body;

  try {
    const check = await db.query(
      'SELECT * FROM Flashcard_Set WHERE user_id = $1 AND name = $2',
      [userId, name]
    );

    if (check.rows.length > 0) {
      return res.status(409).json({ error: 'Set with this name already exists' });
    }

    const result = await db.query(
      'INSERT INTO Flashcard_Set (user_id, name, is_public_FYN) VALUES ($1, $2, $3) RETURNING *',
      [userId, name, isPublic]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Chyba pri vytváraní setu' });
  }
});

module.exports = router;
