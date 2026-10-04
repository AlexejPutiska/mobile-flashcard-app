const dotenv = require('dotenv');
dotenv.config();
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const SECRET_KEY = process.env.JWT_SECRET;
const socket = require('./socket');

//const dummyPassword = 'guest-password-123';
//const multer = require('multer');
//const upload = multer();

const Pool = require('pg').Pool
const pool = new Pool({
  user: process.env.DB_USER ,
  host:process.env.DB_HOST ,
  database:process.env.DB_NAME ,
  password:process.env.DB_PASSWORD ,
  port:process.env.DB_PORT ,
  ssl: { rejectUnauthorized: false }
})

//REGISTRACIA
const registerUser = async (req, res) => {
  const { name, email, password } = req.body;
  const user_role = 'user';

  try {

    if (!name || !email || !password){
      return res.status(400).send('Missing fields')
    }
    const hashedPassword = await bcrypt.hash(password, 10);

    const checkEmail = await pool.query('SELECT * FROM Users WHERE email = $1', [email]);
    if (checkEmail.rows.length > 0) {
      return res.status(409).send('User with this email already exists');
    }

    const result = await pool.query(
      `INSERT INTO Users (name, email, password, user_role)
       VALUES ($1, $2, $3, $4)
       RETURNING user_id`,
      [name, email, hashedPassword, user_role]
    );

    res.status(201).send(`User registered with ID: ${result.rows[0].user_id}`);
  } catch (error) {
    console.error('User registration failed>', error);
    res.status(500).send('User registration failed');
  }
};


//LOGIN 
const loginUser = async (req, res) => {
  const { email, password } = req.body;

  try {
    const result = await pool.query(
      'SELECT * FROM Users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).send('Invalid credentials');
    }

    if (!email || !password) {
      return res.status(400).send("Email and password are required.");
    }

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).send('Wrong password');
    }

    const token = jwt.sign({ userId: user.user_id, email: user.email, userRole: user.user_role }, SECRET_KEY, {
      expiresIn: '24h',
    });

    res.status(200).json({ token,userRole: user.user_role, userName: user.name });
  } catch (error) {
    console.error(error);
    res.status(500).send('Login error');
  }
};



//GUEST LOGIN
const guestLogin = async (req, res) => {
  try {
    const guestId = uuidv4();
    const name = `Guest_${guestId.slice(0, 8)}`;
    const email = `guest_${guestId.slice(0, 8)}@guest.studybro`;
    const password = await bcrypt.hash('guest', 10); 
    const role = 'host';

    const result = await pool.query(
      `INSERT INTO users (name, email, password, user_role)
       VALUES ($1, $2, $3, $4)
       RETURNING user_id, email, user_role`,
      [name, email, password, role]
    );

    const user = result.rows[0];

    const token = jwt.sign(
      {
        userId: user.user_id,
        email: user.email,
        userRole: user.user_role,
      },
      SECRET_KEY,
      { expiresIn: '48h' }
    );

    res.status(200).json({ token, userRole: user.user_role });
  } catch (err) {
    console.error('Guest login failed:', err);
    res.status(500).send('Guest login failed');
  }
};



//VYTVARANIE SETU
const createFlashcardSet = (request, response) => {
  const { name, is_public_FYN } = request.body;
  const userId = request.user.userId;

  if (!name) {
    return response.status(400).send("Missing flashcard set name.");
  }

  
  pool.query(
    'SELECT * FROM Flashcard_Set WHERE user_id = $1 AND name = $2',
    [userId, name],
    (checkError, checkResults) => {
      if (checkError) {
        console.error(checkError);
        return response.status(500).send("Error checking for existing set.");
      }

      if (checkResults.rows.length > 0) {
        return response.status(409).send("Flashcard set with this name already exists.");
      }

     
      pool.query(
        'INSERT INTO Flashcard_Set (user_id, name, is_public_FYN) VALUES ($1, $2, $3) RETURNING *',
        [userId, name, is_public_FYN ?? false],
        (error, results) => {
          if (error) {
            console.error(error);
            return response.status(500).send("Failed to create flashcard set.");
          }

          response.status(201).json({
            message: "Flashcard set created successfully.",
            set: results.rows[0],
          });
        }
      );
    }
  );
};


//ZISKANIE SETU
const getFlashcardsSets = (req, res) => {
  const userId = req.user.userId;

  const query = `
    SELECT *
    FROM Flashcard_set fs
    WHERE fs.user_id = $1
    AND fs.is_public_FYN = false
    ORDER BY fs.set_id ASC
  `;

  pool.query(query, [userId], (error, results) => {
    if (error) {
      console.error('Error fetching flashcards:', error);
      return res.status(500).send('Database error');
    }
    res.status(200).json(results.rows);
  });
};

// DELETE Flashcard Set
const deleteFlashcardSet = (req, res) => {
  const { set_id } = req.params;
  const userId = req.user.userId;

  const query = `
    DELETE FROM Flashcard_Set
    WHERE set_id = $1 AND user_id = $2
    RETURNING *;
  `;

  pool.query(query, [set_id, userId], (err, result) => {
    if (err) {
      console.error("Error deleting set:", err);
      return res.status(500).send("Failed to delete flashcard set.");
    }

    if (result.rows.length === 0) {
      return res.status(404).send("Flashcard set not found or unauthorized.");
    }

    res.status(200).json({
      message: "Flashcard set deleted successfully.",
      deletedSet: result.rows[0],
    });
  });
};


// UPDATE Flashcard Set
const updateFlashcardSet = (req, res) => {
  const { set_id } = req.params;
  const { name, is_public_FYN } = req.body;
  const userId = req.user.userId;

  if (!name) {
    return res.status(400).send("Set name is required.");
  }

  const query = `
    UPDATE Flashcard_Set
    SET name = $1,
        is_public_FYN = $2,
        updated_at = CURRENT_TIMESTAMP
    WHERE set_id = $3 AND user_id = $4
    RETURNING *;
  `;

  pool.query(query, [name, is_public_FYN ?? false, set_id, userId], (err, result) => {
    if (err) {
      console.error("Error updating set:", err);
      return res.status(500).send("Failed to update flashcard set.");
    }

    if (result.rows.length === 0) {
      return res.status(404).send("Flashcard set not found or unauthorized.");
    }

    res.status(200).json({
      message: "Flashcard set updated successfully.",
      updatedSet: result.rows[0],
    });
  });
};


//GET Flashcard
const getFlashcardsBySet = (req, res) => {
  const userId = req.user.userId;
  const setId = req.params.set_id;

  const query = `
    SELECT f.flashcard_id, f.name, f.data_type, f.front_side, f.back_side,
           encode(f.image_front, 'base64') AS image_front,
           encode(f.image_back, 'base64') AS image_back
    FROM Flashcards f
    JOIN Flashcard_Set fs ON f.set_id = fs.set_id
    WHERE f.set_id = $1 AND fs.user_id = $2
    ORDER BY f.flashcard_id ASC
  `;

  pool.query(query, [setId,userId], (error, results) => {
    if (error) {
      console.error('Error fetching flashcards:', error);
      return res.status(500).send('Database error');
    }

    res.status(200).json(results.rows);
  });
};



//CREATE Flashcard 
const createFlashcard = async (req, res) => {
  const { set_id, name, data_type, front_side, back_side } = req.body;
  const userId = req.user.userId;

  if (!set_id || !name || !data_type) {
    return res.status(400).send("Missing fields.");
  }

  const imageFront = req.files?.image_front?.[0]?.buffer || null;
  const imageBack = req.files?.image_back?.[0]?.buffer || null;

  try {
    // Overenie ci mu patri
    const check = await pool.query(
      'SELECT * FROM Flashcard_Set WHERE set_id = $1 AND user_id = $2',
      [set_id, userId]
    );

    if (check.rows.length === 0) {
      return res.status(403).send("Not authorized to add flashcard to this set.");
    }

    // vlozime
    const result = await pool.query(
      `INSERT INTO Flashcards 
       (set_id, name, data_type, front_side, back_side, image_front, image_back) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [set_id, name, data_type, front_side, back_side, imageFront, imageBack]
    );

    res.status(201).json({
      message: "Flashcard created",
      flashcard: result.rows[0],
    });

  } catch (err) {
    console.error('Error creating flashcard:', err);
    res.status(500).send("Database error");
  }
};



//DELETE Flashcard
const deleteFlashcard = (req, res) => {
  const flashcardId = parseInt(req.params.flashcard_id);
  const userId = req.user.userId;

  if (!flashcardId) {
    return res.status(400).send("Missing flashcard ID.");
  }

  const query = `
    DELETE FROM Flashcards 
    WHERE flashcard_id = $1 
    AND set_id IN (
      SELECT set_id FROM Flashcard_Set WHERE user_id = $2
    )
    RETURNING *;
  `;

  pool.query(query, [flashcardId, userId], (err, result) => {
    if (err) {
      console.error('Database error:', err);
      return res.status(500).send("Database error.");
    }

    if (result.rows.length === 0) {
      return res.status(404).send("Flashcard not found or not authorized.");
    }

    res.status(200).json({
      message: "Flashcard deleted successfully.",
      deleted: result.rows[0]
    });
  });
};



// UPDATE Flashcard
const updateFlashcard = (req, res) => {
  const flashcardId = parseInt(req.params.flashcard_id);
  const userId = req.user.userId;

  const { name, front_side, back_side, data_type, remove_image_front, remove_image_back } = req.body;
  const imageFront = req.files?.image_front?.[0]?.buffer || null;
  const imageBack = req.files?.image_back?.[0]?.buffer || null;

  const fields = [];
  const values = [];
  let idx = 1;

  
  if (name) {
    fields.push(`name = $${idx++}`);
    values.push(name);
  }

  
  if (data_type) {
    fields.push(`data_type = $${idx++}`);
    values.push(data_type);
  }

  
  if (front_side !== undefined) {
    fields.push(`front_side = $${idx++}`);
    values.push(front_side);
  }

  if (back_side !== undefined) {
    fields.push(`back_side = $${idx++}`);
    values.push(back_side);
  }

  
  if (imageFront !== null) {
    fields.push(`image_front = $${idx++}`);
    values.push(imageFront);
  }

  if (imageBack !== null) {
    fields.push(`image_back = $${idx++}`);
    values.push(imageBack);
  }

  // Odstranenie
  if (remove_image_front === 'true') {
    
    if (imageFront !== null) {
      return res.status(400).send('Conflict: Cannot send image and remove flag at once (front).');
    }
    fields.push(`image_front = NULL`);
  }

  if (remove_image_back === 'true') {
    if (imageBack !== null) {
      return res.status(400).send('Conflict: Cannot send image and remove flag at once (back).');
    }
    fields.push(`image_back = NULL`);
  }


  if (fields.length === 0) {
    return res.status(400).send('Nothing to update.');
  }

 
  const query = `
    UPDATE Flashcards 
    SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
    WHERE flashcard_id = $${idx}
      AND set_id IN (
        SELECT set_id FROM Flashcard_Set WHERE user_id = $${idx + 1}
      )
    RETURNING *;
  `;
  values.push(flashcardId, userId);

  // Spustenie query
  pool.query(query, values, (err, result) => {
    if (err) {
      console.error('Error updating flashcard:', err);
      return res.status(500).send('Database error');
    }

    if (result.rowCount === 0) {
      return res.status(404).send('Flashcard not found or not authorized.');
    }

    res.status(200).json({
      message: 'Flashcard updated successfully',
      flashcard: result.rows[0],
    });
  });
};



//RESET Statistics
const resetStatistics = (req, res) => {
  const userId = req.user.userId;

  const query = `
    DELETE FROM learning_sessions
    WHERE user_id = $1
  `;

  pool.query(query, [userId], (err, result) => {
    if (err) {
      console.error('Error resetting statistics:', err);
      return res.status(500).send("Database error");
    }

    res.status(200).json({
      message: "Statistics reset successfully",
      deletedCount: result.rowCount,
    });
  });
};



//UPDATE statistics
const updateStatistics = (req, res) => {
  const userId = req.user.userId;
  const { avg_accuracy, total_learning_time, best_learning_streak, current_learning_streak } = req.body;

  const fields = [];
  const values = [];
  let idx = 1;

  if (avg_accuracy !== undefined) {
    fields.push(`avg_accuracy = $${idx++}`);
    values.push(avg_accuracy);
  }
  if (total_learning_time !== undefined) {
    fields.push(`total_learning_time = $${idx++}`);
    values.push(total_learning_time);
  }
  if (best_learning_streak !== undefined) {
    fields.push(`best_learning_streak = $${idx++}`);
    values.push(best_learning_streak);
  }
  if (current_learning_streak !== undefined) {
    fields.push(`current_learning_streak = $${idx++}`);
    values.push(current_learning_streak);
  }

  if (fields.length === 0) {
    return res.status(400).send("No statistics to update.");
  }

  const query = `
    UPDATE Users SET ${fields.join(', ')}
    WHERE user_id = $${idx}
    RETURNING avg_accuracy, total_learning_time, best_learning_streak, current_learning_streak
  `;
  values.push(userId);

  pool.query(query, values, (err, result) => {
    if (err) {
      console.error('Error updating statistics:', err);
      return res.status(500).send("Database error");
    }

    res.status(200).json({
      message: "Statistics updated",
      statistics: result.rows[0],
    });
  });
};


//FCM TOKEN PRE PUSH NOTIFIKACIE 
const saveNotificationToken = (req, res) => {
  const userId = req.user.userId;
  const { fcm_token } = req.body;

  if (!fcm_token) {
    return res.status(400).send("Missing FCM token.");
  }

  // Najprv overenie
  const checkQuery = `
    SELECT * FROM User_Devices 
    WHERE user_id = $1 AND fcm_token = $2
  `;

  pool.query(checkQuery, [userId, fcm_token], (err, result) => {
    if (err) {
      console.error("Database error:", err);
      return res.status(500).send("Database error.");
    }

    if (result.rows.length > 0) {
      return res.status(200).json({ message: "Token already registered." });
    }

    // Ak nie, vlozime
    const insertQuery = `
      INSERT INTO User_Devices (user_id, fcm_token)
      VALUES ($1, $2)
      RETURNING *
    `;

    pool.query(insertQuery, [userId, fcm_token], (err, result) => {
      if (err) {
        console.error("Error saving token:", err);
        return res.status(500).send("Failed to save token.");
      }

      res.status(201).json({
        message: "FCM token saved successfully.",
        device: result.rows[0]
      });
    });
  });
};

//GET PREFERENCIE (DARK MODE)
const getUserPreferences = (req, res) => {
  const userId = req.user.userId;

  pool.query(
    'SELECT darkmode_FYN FROM Users WHERE user_id = $1',
    [userId],
    (err, result) => {
      if (err) {
        console.error(err);
        return res.status(500).send('Database error.');
      }

      if (result.rows.length === 0) {
        return res.status(404).send('User not found.');
      }

      res.status(200).json({
        dark_mode: result.rows[0].darkmode_fyn
      });
    }
  );
};


//AKTUALIZACIA preferencii
const updateUserPreferences = (req, res) => {
  const userId = req.user.userId;
  const { dark_mode } = req.body;

  if (typeof dark_mode !== 'boolean') {
    return res.status(400).send("dark_mode must be boolean.");
  }

  pool.query(
    'UPDATE Users SET darkmode_FYN = $1 WHERE user_id = $2 RETURNING darkmode_FYN',
    [dark_mode, userId],
    (err, result) => {
      if (err) {
        console.error(err);
        return res.status(500).send("Database error.");
      }

      res.status(200).json({
        message: "Preferences updated.",
        dark_mode: result.rows[0].darkmode_fyn
      });
    }
  );
};


const getPublicSets = (req, res) => {
  const query = `
    SELECT set_id, name, user_id, created_at, is_public_fyn, updated_at
    FROM Flashcard_Set
    WHERE is_public_FYN = true
    ORDER BY created_at DESC
  `;

  pool.query(query, (err, result) => {
    if (err) {
      console.error("Error fetching public sets:", err);
      return res.status(500).send("Database error");
    }

    res.status(200).json(result.rows);
  });
};




const getPublicFlashcardsBySet = (req, res) => {
  const setId = req.params.set_id;

  const query = `
    SELECT f.flashcard_id, f.name, f.data_type, f.front_side, f.back_side,
           encode(f.image_front, 'base64') AS image_front,
           encode(f.image_back, 'base64') AS image_back
    FROM Flashcards f
    JOIN Flashcard_Set s ON f.set_id = s.set_id
    WHERE f.set_id = $1 AND s.is_public_FYN = true
    ORDER BY f.flashcard_id ASC
  `;

  pool.query(query, [setId], (err, result) => {
    if (err) {
      console.error("Error fetching public flashcards:", err);
      return res.status(500).send("Database error");
    }

    res.status(200).json(result.rows);
  });
};


const createPublicSet = (req, res) => {
  const { name } = req.body;
  const userId = req.user.userId;

  if (!name) {
    return res.status(400).send("Missing set name.");
  }

  // Overenie role 
  pool.query(
    'SELECT user_role FROM Users WHERE user_id = $1',
    [userId],
    (err, result) => {
      if (err) {
        console.error("Error fetching user role:", err);
        return res.status(500).send("Database error.");
      }

      if (result.rows.length === 0) {
        return res.status(404).send("User not found.");
      }

      const role = result.rows[0].user_role;
      if (role !== 'admin') {
        return res.status(403).send("Unauthorized: Only admin can create public sets.");
      }

      // Ak je admin → pokracuj
      pool.query(
        `INSERT INTO Flashcard_Set (user_id, name, is_public_FYN) 
         VALUES ($1, $2, true) RETURNING *`,
        [userId, name],
        (insertErr, insertResult) => {
          if (insertErr) {
            console.error("Error creating public set:", insertErr);
            return res.status(500).send("Database error");
          }


          // ✅ Vysielame správu cez WebSocket
          const io = socket.getIO();
          const createdSet = insertResult.rows[0];
          io.emit('newPublicSet', {
            title: createdSet.name,
            created_by: userId,
            created_at: new Date()
          });

          res.status(201).json({
            message: "Public set created",
            set: createdSet
          });
        }
      );
    }
  );
};



const createPublicFlashcard = (req, res) => {
  const { set_id, name, data_type, front_side, back_side } = req.body;
  const userId = req.user.userId;
  const role = req.user.user_role;

  if (role !== 'admin') {
    return res.status(403).send("Unauthorized: Only admin can add public flashcards.");
  }

  if (!set_id || !name || !data_type) {
    return res.status(400).send("Missing required fields.");
  }

  const imageFront = req.files?.image_front?.[0]?.buffer || null;
  const imageBack = req.files?.image_back?.[0]?.buffer || null;

  pool.query(
    `INSERT INTO Flashcards 
     (set_id, name, data_type, front_side, back_side, image_front, image_back)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [set_id, name, data_type, front_side || "", back_side || "", imageFront, imageBack],
    (err, result) => {
      if (err) {
        console.error("Error inserting public flashcard:", err);
        return res.status(500).send("Database error");
      }

      res.status(201).json({
        message: "Public flashcard created",
        flashcard: result.rows[0]
      });
    }
  );
};



const deletePublicSet = (req, res) => {
  const setId = parseInt(req.params.set_id);
  const role = req.user.user_role;

  if (role !== 'admin') {
    return res.status(403).send("Unauthorized: Only admin can delete public sets.");
  }

  if (!setId) {
    return res.status(400).send("Missing set ID.");
  }

  pool.query(
    `DELETE FROM Flashcard_Set 
     WHERE set_id = $1 AND is_public_FYN = true 
     RETURNING *`,
    [setId],
    (err, result) => {
      if (err) {
        console.error("Error deleting public set:", err);
        return res.status(500).send("Database error");
      }

      if (result.rowCount === 0) {
        return res.status(404).send("Public set not found.");
      }

      res.status(200).json({
        message: "Public set deleted",
        deleted: result.rows[0]
      });
    }
  );
};



const deletePublicFlashcard = (req, res) => {
  const flashcardId = parseInt(req.params.flashcard_id);
  const role = req.user.user_role;

  if (role !== 'admin') {
    return res.status(403).send("Unauthorized: Only admin can delete public flashcards.");
  }

  if (!flashcardId) {
    return res.status(400).send("Missing flashcard ID.");
  }

  const query = `
    DELETE FROM Flashcards 
    WHERE flashcard_id = $1 
    AND set_id IN (
      SELECT set_id FROM Flashcard_Set WHERE is_public_FYN = true
    )
    RETURNING *;
  `;

  pool.query(query, [flashcardId], (err, result) => {
    if (err) {
      console.error("Error deleting public flashcard:", err);
      return res.status(500).send("Database error");
    }

    if (result.rowCount === 0) {
      return res.status(404).send("Public flashcard not found.");
    }

    res.status(200).json({
      message: "Public flashcard deleted",
      deleted: result.rows[0]
    });
  });
};




const getSingleFlashcardSet = (req, res) => {
  const setId = parseInt(req.params.set_id);
  const userId = req.user.userId;

  const query = `
    SELECT *
    FROM Flashcard_Set
    WHERE set_id = $1 AND user_id = $2
  `;


  pool.query(query, [setId, userId], (err, result) => {
    if (err) {
      console.error('Error fetching single set:', err);
      return res.status(500).send('Database error');
    }

    if (result.rows.length === 0) {
      return res.status(404).send('Set not found or unauthorized');
    }

    res.status(200).json(result.rows[0]);
  });
};


const getFlashcardById = (req, res) => {
  const flashcardId = parseInt(req.params.flashcard_id);
  const userId = req.user.userId;

  if (!flashcardId) {
    return res.status(400).send("Missing flashcard ID.");
  }

  const query = `
    SELECT f.flashcard_id, f.set_id, f.name, f.data_type, f.front_side, f.back_side,
           encode(f.image_front, 'base64') AS image_front,
           encode(f.image_back, 'base64') AS image_back
    FROM Flashcards f
    JOIN Flashcard_Set s ON f.set_id = s.set_id
    WHERE f.flashcard_id = $1 AND s.user_id = $2
  `;

  pool.query(query, [flashcardId, userId], (err, result) => {
    if (err) {
      console.error("Error fetching flashcard:", err);
      return res.status(500).send("Database error.");
    }

    if (result.rows.length === 0) {
      return res.status(404).send("Flashcard not found or unauthorized.");
    }

    res.status(200).json(result.rows[0]);
  });
};



const getCurrentUser = (req, res) => {
  const userId = req.user.userId;

  const query = `
    SELECT user_id, name, email, user_role
    FROM Users
    WHERE user_id = $1
  `;

  pool.query(query, [userId], (err, result) => {
    if (err) {
      console.error("Error fetching user:", err);
      return res.status(500).send("Database error");
    }

    if (result.rows.length === 0) {
      return res.status(404).send("User not found");
    }

    res.status(200).json(result.rows[0]);
  });
};


// vložiť nový session
const createLearningSession = ({userId, start_time, end_time, correct_answers, total_answers}) =>
  pool.query(`
    INSERT INTO Learning_Sessions(user_id, start_time, end_time, correct_answers, total_answers)
    VALUES($1,$2,$3,$4,$5) RETURNING *;
  `, [userId, start_time, end_time, correct_answers, total_answers]);


//STATISTIKY
// získať všetky 4 agregáty naraz
const getUserStatistics = async (userId) => {
  const result = await pool.query(`
    WITH sessions AS (
      SELECT *
      FROM learning_sessions
      WHERE user_id = $1
    ),
    agg AS (
      SELECT
        COALESCE(SUM(correct_answers)::float / NULLIF(SUM(total_answers), 0), 0) AS avg_accuracy,
        COALESCE(SUM(EXTRACT(EPOCH FROM end_time - start_time)), 0) AS total_time_secs
      FROM sessions
    ),
    dates AS (
      SELECT DISTINCT DATE(start_time) AS d
      FROM sessions
    ),
    numbered AS (
      SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS rn
      FROM dates
    ),
    grouped AS (
      SELECT d, d - (rn * INTERVAL '1 day') AS grp
      FROM numbered
    ),
    streaks AS (
      SELECT grp, COUNT(*) AS length, MAX(d) AS last_day
      FROM grouped
      GROUP BY grp
    ),
    best AS (
      SELECT MAX(length) AS best_streak FROM streaks
    ),
    current AS (
      SELECT length AS current_streak
      FROM streaks
      WHERE last_day = (SELECT MAX(d) FROM dates)
      LIMIT 1
    )
    SELECT
      agg.avg_accuracy,
      agg.total_time_secs,
      COALESCE(best.best_streak, 0) AS best_streak,
      COALESCE(current.current_streak, 0) AS current_streak
    FROM agg
    LEFT JOIN best ON true
    LEFT JOIN current ON true;
  `, [userId]);

  return result.rows[0]; 
};






module.exports = {
  registerUser,
  guestLogin,
  getFlashcardsSets,
  deleteFlashcardSet,
  updateFlashcardSet,
  createFlashcardSet,
  createFlashcard,
  getFlashcardsBySet,
  deleteFlashcard,
  updateFlashcard,
  getUserStatistics,
  resetStatistics,
  updateStatistics,
  saveNotificationToken,
  getUserPreferences,
  updateUserPreferences,
  getPublicSets,
  getPublicFlashcardsBySet,
  createPublicSet,
  deletePublicSet,
  deletePublicFlashcard,
  createPublicFlashcard,
  getSingleFlashcardSet,
  getFlashcardById,
  getCurrentUser,
  createLearningSession,
  loginUser
}