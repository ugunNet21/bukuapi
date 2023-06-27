import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider<ThemeModeNotifier>(
      create: (_) => ThemeModeNotifier(),
      child: MyBooks(),
    ),
  );
}

class ThemeModeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class MyBooks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeNotifier>(
      builder: (context, themeModeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Daftar Buku API',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeModeNotifier.themeMode,
          home: BookListScreen(),
        );
      },
    );
  }
}

class Book {
  final String title;
  final String subtitle;
  final String image;
  final String url;
  String authors;
  String publisher;
  String language;
  String isbn10;
  String isbn13;
  String pages;
  String year;
  String rating;
  String desc;
  String price;
  bool isDownloaded;

  Book({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.url,
    required this.authors,
    required this.publisher,
    required this.language,
    required this.isbn10,
    required this.isbn13,
    required this.pages,
    required this.year,
    required this.rating,
    required this.desc,
    required this.price,
    required this.isDownloaded,
  });
}

class BookListScreen extends StatefulWidget {
  @override
  _BookListScreenState createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List<Book> books = [];
  List<Book> filteredBooks = [];
  bool isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    fetchBooks();
    setDownloadStatus();
  }

  Future<void> fetchBooks() async {
    final response = await http.get(
        Uri.parse('https://api.itbook.store/1.0/search/Flutter%20Developer'));

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      print(response.body);

      setState(() {
        final bookList = jsonData['books'] as List<dynamic>;

        books = bookList
            .map((bookData) => Book(
                  title: bookData['title'],
                  subtitle: bookData['subtitle'],
                  image: bookData['image'],
                  url: bookData['url'],
                  authors: '',
                  publisher: '',
                  language: '',
                  isbn10: '',
                  isbn13: '',
                  pages: '',
                  year: '',
                  rating: '',
                  desc: '',
                  price: '',
                  isDownloaded: false,
                ))
            .toList();

        filteredBooks = books;
      });

      // Menampilkan data setiap detail buku
      for (final book in books) {
        await fetchBookDetails(book);
      }
    } else {
      throw Exception('Gagal');
    }
  }

  Future<void> fetchBookDetails(Book book) async {
    final response = await http
        .get(Uri.parse('https://api.itbook.store/1.0/books/9781484206485'));

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      print(response.body);

      setState(() {
        book.authors = jsonData['authors'];
        book.publisher = jsonData['publisher'];
        book.language = jsonData['language'];
        book.isbn10 = jsonData['isbn10'];
        book.isbn13 = jsonData['isbn13'];
        book.pages = jsonData['pages'];
        book.year = jsonData['year'];
        book.rating = jsonData['rating'];
        book.desc = jsonData['desc'];
        book.price = jsonData['price'];

        filteredBooks = books;
        isDataLoaded = true;
      });
    } else {
      setState(() {
        isDataLoaded = false;
      });
      throw Exception('Gagal mengambil data');
    }
  }

  void setDownloadStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? downloadedBooks = prefs.getStringList('downloaded_books');

    if (downloadedBooks != null) {
      for (final book in books) {
        if (downloadedBooks.contains(book.title)) {
          setState(() {
            book.isDownloaded = true;
          });
        }
      }
    }
  }

  void toggleDownloadStatus(Book book) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? downloadedBooks = prefs.getStringList('downloaded_books');

    if (downloadedBooks == null) {
      downloadedBooks = [];
    }

    setState(() {
      if (book.isDownloaded) {
        book.isDownloaded = false;
        downloadedBooks?.remove(book.title);
      } else {
        book.isDownloaded = true;
        downloadedBooks?.add(book.title);
      }
    });

    prefs.setStringList('downloaded_books', downloadedBooks);
  }

  void filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredBooks = books;
      } else {
        filteredBooks = books
            .where((book) =>
                book.title.toLowerCase().contains(query.toLowerCase()) ||
                book.subtitle.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Buku dari API'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              final Book? selectedBook = await showSearch(
                context: context,
                delegate: BookSearchDelegate(books),
              );

              if (selectedBook != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookDetailScreen(
                      book: selectedBook,
                      themeModeNotifier: context.read<ThemeModeNotifier>(),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: isDataLoaded
          ? ListView.builder(
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                return Card(
                  child: ListTile(
                    leading: CachedNetworkImage(
                      imageUrl: book.image,
                      placeholder: (context, url) =>
                          CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          Icon(Icons.error),
                    ),
                    title: Text(book.title),
                    subtitle: Text(book.subtitle),
                    trailing: IconButton(
                      icon: Icon(
                        book.isDownloaded ? Icons.check : Icons.download,
                      ),
                      onPressed: () {
                        toggleDownloadStatus(book);
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookDetailScreen(
                            book: book,
                            themeModeNotifier: context.read<ThemeModeNotifier>(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}

class BookSearchDelegate extends SearchDelegate<Book> {
  final List<Book> books;

  BookSearchDelegate(this.books);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null!);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredBooks = books
        .where((book) =>
            book.title.toLowerCase().contains(query.toLowerCase()) ||
            book.subtitle.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return ListTile(
          title: Text(book.title),
          subtitle: Text(book.subtitle),
          onTap: () {
            close(context, book);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredBooks = books
        .where((book) =>
            book.title.toLowerCase().contains(query.toLowerCase()) ||
            book.subtitle.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return ListTile(
          title: Text(book.title),
          subtitle: Text(book.subtitle),
          onTap: () {
            query = book.title;
            close(context, book);
          },
        );
      },
    );
  }
}

class BookDetailScreen extends StatelessWidget {
  final Book book;
  final ThemeModeNotifier themeModeNotifier;

  BookDetailScreen({
    required this.book,
    required this.themeModeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Buku'),
        actions: [
          IconButton(
            icon: Icon(
              themeModeNotifier.themeMode == ThemeMode.light
                  ? Icons.lightbulb_outline
                  : Icons.lightbulb,
            ),
            onPressed: () {
              final newThemeMode = themeModeNotifier.themeMode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
              themeModeNotifier.themeMode = newThemeMode;
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          CachedNetworkImage(
            imageUrl: book.image,
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
          ListTile(
            title: Text(book.title),
            subtitle: Text(book.subtitle),
          ),
          ListTile(
            title: Text('Authors'),
            subtitle: Text(book.authors),
          ),
          ListTile(
            title: Text('Publisher'),
            subtitle: Text(book.publisher),
          ),
          ListTile(
            title: Text('Language'),
            subtitle: Text(book.language),
          ),
          ListTile(
            title: Text('ISBN-10'),
            subtitle: Text(book.isbn10),
          ),
          ListTile(
            title: Text('ISBN-13'),
            subtitle: Text(book.isbn13),
          ),
          ListTile(
            title: Text('Pages'),
            subtitle: Text(book.pages),
          ),
          ListTile(
            title: Text('Year'),
            subtitle: Text(book.year),
          ),
          ListTile(
            title: Text('Rating'),
            subtitle: Text(book.rating),
          ),
          ListTile(
            title: Text('Description'),
            subtitle: Text(book.desc),
          ),
          ListTile(
            title: Text('Price'),
            subtitle: Text(book.price),
          ),
        ],
      ),
    );
  }
}
