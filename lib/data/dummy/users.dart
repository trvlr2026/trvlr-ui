import '../models/user.dart';

const currentUserTemplate = User(
  id: 'u_me',
  displayName: 'You',
  email: 'traveler@trvlr.app',
  homeDistrict: 'Bengaluru Urban',
  homeState: 'Karnataka',
);

const dummyLeaderboardUsers = <User>[
  User(id: 'u1', displayName: 'Arjun Mehta', email: 'arjun@example.com', homeDistrict: 'Mumbai City', homeState: 'Maharashtra'),
  User(id: 'u2', displayName: 'Priya Sharma', email: 'priya@example.com', homeDistrict: 'New Delhi', homeState: 'Delhi'),
  User(id: 'u3', displayName: 'Rahul Nair', email: 'rahul@example.com', homeDistrict: 'Bengaluru Urban', homeState: 'Karnataka'),
  User(id: 'u4', displayName: 'Sneha Reddy', email: 'sneha@example.com', homeDistrict: 'Hyderabad', homeState: 'Telangana'),
  User(id: 'u5', displayName: 'Vikram Singh', email: 'vikram@example.com', homeDistrict: 'Jaipur', homeState: 'Rajasthan'),
  User(id: 'u6', displayName: 'Ananya Das', email: 'ananya@example.com', homeDistrict: 'Kolkata', homeState: 'West Bengal'),
  User(id: 'u7', displayName: 'Karan Patel', email: 'karan@example.com', homeDistrict: 'Ahmedabad', homeState: 'Gujarat'),
  User(id: 'u8', displayName: 'Meera Iyer', email: 'meera@example.com', homeDistrict: 'Chennai', homeState: 'Tamil Nadu'),
  User(id: 'u9', displayName: 'Rohan Gupta', email: 'rohan@example.com', homeDistrict: 'Lucknow', homeState: 'Uttar Pradesh'),
  User(id: 'u10', displayName: 'Divya Menon', email: 'divya@example.com', homeDistrict: 'Kochi', homeState: 'Kerala'),
  User(id: 'u11', displayName: 'Amit Verma', email: 'amit@example.com', homeDistrict: 'Pune', homeState: 'Maharashtra'),
  User(id: 'u12', displayName: 'Kavya Joshi', email: 'kavya@example.com', homeDistrict: 'Mysuru', homeState: 'Karnataka'),
  User(id: 'u13', displayName: 'Suresh Pillai', email: 'suresh@example.com', homeDistrict: 'Thiruvananthapuram', homeState: 'Kerala'),
  User(id: 'u14', displayName: 'Neha Kapoor', email: 'neha@example.com', homeDistrict: 'Chandigarh', homeState: 'Punjab'),
  User(id: 'u15', displayName: 'Dev Malhotra', email: 'dev@example.com', homeDistrict: 'Gurugram', homeState: 'Haryana'),
  User(id: 'u16', displayName: 'Isha Banerjee', email: 'isha@example.com', homeDistrict: 'Darjeeling', homeState: 'West Bengal'),
  User(id: 'u17', displayName: 'Harsh Desai', email: 'harsh@example.com', homeDistrict: 'Surat', homeState: 'Gujarat'),
  User(id: 'u18', displayName: 'Pooja Rao', email: 'pooja@example.com', homeDistrict: 'Visakhapatnam', homeState: 'Andhra Pradesh'),
  User(id: 'u19', displayName: 'Nikhil Thomas', email: 'nikhil@example.com', homeDistrict: 'Bengaluru Urban', homeState: 'Karnataka'),
  User(id: 'u20', displayName: 'Lakshmi Krishnan', email: 'lakshmi@example.com', homeDistrict: 'Coimbatore', homeState: 'Tamil Nadu'),
];

/// Pre-assigned dummy points for leaderboard users (userId -> points, visits)
const dummyUserScores = <String, ({int points, int visits})>{
  'u1': (points: 1240, visits: 18),
  'u2': (points: 1180, visits: 16),
  'u3': (points: 1050, visits: 15),
  'u4': (points: 980, visits: 14),
  'u5': (points: 920, visits: 13),
  'u6': (points: 870, visits: 12),
  'u7': (points: 810, visits: 11),
  'u8': (points: 760, visits: 11),
  'u9': (points: 700, visits: 10),
  'u10': (points: 650, visits: 9),
  'u11': (points: 600, visits: 9),
  'u12': (points: 550, visits: 8),
  'u13': (points: 500, visits: 8),
  'u14': (points: 460, visits: 7),
  'u15': (points: 420, visits: 7),
  'u16': (points: 380, visits: 6),
  'u17': (points: 340, visits: 6),
  'u18': (points: 300, visits: 5),
  'u19': (points: 260, visits: 5),
  'u20': (points: 220, visits: 4),
};
