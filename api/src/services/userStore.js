const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const User = require('../models/User');

const dbFilePath = path.join(__dirname, '../../data/local_users.json');

// Đảm bảo thư mục data tồn tại
const ensureDataDir = () => {
  const dir = path.dirname(dbFilePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

// Đọc dữ liệu local
const readLocalUsers = () => {
  ensureDataDir();
  if (!fs.existsSync(dbFilePath)) {
    // Tạo sẵn tài khoản mẫu cho Huỳnh Mạnh Trí
    const defaultSalt = bcrypt.genSaltSync(10);
    const defaultHash = bcrypt.hashSync('123456', defaultSalt);
    const initialData = [
      {
        _id: '672000000000000000000001',
        fullName: 'Huỳnh Mạnh Trí',
        email: 'hmtrikhmt2411044@student.ctuet.edu.vn',
        passwordHash: defaultHash,
        role: 'member',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];
    fs.writeFileSync(dbFilePath, JSON.stringify(initialData, null, 2), 'utf8');
    return initialData;
  }
  try {
    const raw = fs.readFileSync(dbFilePath, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    return [];
  }
};

// Lưu dữ liệu local
const writeLocalUsers = (users) => {
  ensureDataDir();
  fs.writeFileSync(dbFilePath, JSON.stringify(users, null, 2), 'utf8');
};

const isMongooseConnected = () => mongoose.connection.readyState === 1;

module.exports = {
  async findByEmail(email) {
    const cleanEmail = email.trim().toLowerCase();
    if (isMongooseConnected()) {
      return await User.findOne({ email: cleanEmail });
    }
    const users = readLocalUsers();
    const found = users.find((u) => u.email.toLowerCase() === cleanEmail);
    if (!found) return null;
    return {
      ...found,
      isValidPassword: async (pwd) => await bcrypt.compare(pwd, found.passwordHash),
      toJSON: () => {
        const copy = { ...found };
        delete copy.passwordHash;
        return copy;
      },
    };
  },

  async findById(id) {
    const idStr = String(id);
    if (isMongooseConnected()) {
      return await User.findById(idStr);
    }
    const users = readLocalUsers();
    const found = users.find((u) => String(u._id) === idStr);
    if (!found) return null;
    return {
      ...found,
      isValidPassword: async (pwd) => await bcrypt.compare(pwd, found.passwordHash),
      toJSON: () => {
        const copy = { ...found };
        delete copy.passwordHash;
        return copy;
      },
    };
  },

  async createUser({ fullName, email, passwordHash }) {
    const cleanEmail = email.trim().toLowerCase();
    if (isMongooseConnected()) {
      return await User.create({ fullName: fullName.trim(), email: cleanEmail, passwordHash });
    }
    const users = readLocalUsers();
    const newUser = {
      _id: new mongoose.Types.ObjectId().toString(),
      fullName: fullName.trim(),
      email: cleanEmail,
      passwordHash,
      role: 'member',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    users.push(newUser);
    writeLocalUsers(users);
    return {
      ...newUser,
      toJSON: () => {
        const copy = { ...newUser };
        delete copy.passwordHash;
        return copy;
      },
    };
  },

  async updateProfile(id, updates) {
    const idStr = String(id);
    if (isMongooseConnected()) {
      return await User.findByIdAndUpdate(idStr, updates, { new: true, runValidators: true });
    }
    const users = readLocalUsers();
    const idx = users.findIndex((u) => String(u._id) === idStr);
    if (idx === -1) return null;
    if (updates.fullName) users[idx].fullName = updates.fullName;
    if (updates.avatarUrl !== undefined) users[idx].avatarUrl = updates.avatarUrl;
    users[idx].updatedAt = new Date().toISOString();
    writeLocalUsers(users);
    const updated = users[idx];
    return {
      ...updated,
      toJSON: () => {
        const copy = { ...updated };
        delete copy.passwordHash;
        return copy;
      },
    };
  },

  async updatePassword(id, newPasswordHash) {
    const idStr = String(id);
    if (isMongooseConnected()) {
      const user = await User.findById(idStr);
      if (!user) return false;
      user.passwordHash = newPasswordHash;
      await user.save();
      return true;
    }
    const users = readLocalUsers();
    const idx = users.findIndex((u) => String(u._id) === idStr);
    if (idx === -1) return false;
    users[idx].passwordHash = newPasswordHash;
    users[idx].updatedAt = new Date().toISOString();
    writeLocalUsers(users);
    return true;
  },

  async searchUsers(query = '', excludeUserId = null) {
    const excludeStr = excludeUserId ? String(excludeUserId) : null;
    if (isMongooseConnected()) {
      const filter = {};
      if (query && query.trim()) {
        filter.$or = [
          { fullName: { $regex: query.trim(), $options: 'i' } },
          { email: { $regex: query.trim(), $options: 'i' } },
        ];
      }
      if (excludeStr) {
        filter._id = { $ne: excludeStr };
      }
      return await User.find(filter).select('_id fullName email role avatarUrl').limit(30);
    }
    const users = readLocalUsers();
    return users
      .filter((u) => {
        if (excludeStr && String(u._id) === excludeStr) return false;
        if (!query || !query.trim()) return true;
        const q = query.trim().toLowerCase();
        return (
          (u.fullName && u.fullName.toLowerCase().includes(q)) ||
          (u.email && u.email.toLowerCase().includes(q))
        );
      })
      .slice(0, 30)
      .map((u) => ({
        _id: u._id,
        fullName: u.fullName,
        email: u.email,
        role: u.role,
        avatarUrl: u.avatarUrl,
      }));
  },
};
